#!/usr/bin/env python

import os, sys
import asyncore
import resource

class StringDispatcher(asyncore.file_dispatcher):
    def __init__(self, fd, string, **kwargs):
        asyncore.file_dispatcher.__init__(self, fd, **kwargs)
        self.buffer = string

    def readable(self):
        return False

    def handle_write(self):
        sent = self.send(self.buffer)

        self.buffer = self.buffer[sent:]
        if len(self.buffer) == 0:
            self.close()

class BufferDispatcher(asyncore.file_dispatcher):
    def __init__(self, fd, **kwargs):
        asyncore.file_dispatcher.__init__(self, fd, **kwargs)
        self.buffer = bytearray()

    def writable(self):
        return False

    def handle_read(self):
        self.buffer.extend(self.recv(4096))

    def result(self):
        return self.buffer

class StderrDispatcher(asyncore.file_dispatcher):
    """ Echoes an FD to the test's stderr.
    We want the child process' stderr to go to the test's stderr, but
    we also want to use unittest's --buffer option. Unfortunately that
    doesn't redirect FD 2 like it should; it replaces sys.stderr with
    a StringIO. We therefore have to use a pipe.
    """

    def writable(self):
        return False

    def handle_read(self):
        sys.stderr.write(self.recv(4096))


class Monitor(object):

    def __init__(self, instr = None, copies = 1):
        monitor_exec = os.getenv('TEST_MONITOR_EXEC')
        if monitor_exec is None:
            raise IOError('TEXT_MONITOR_EXEC is not set')
        if not os.path.isfile(monitor_exec):
            raise IOError('TEST_MONITOR_EXEC file not found')


        device_uri = 'socket://printer:9100'
        args = [ device_uri, '1', 'lpr', 'test-job', str(copies), '' ]
        env = {
                'DEVICE_URI': device_uri,
                'PRINTER': 'test-printer',
                'FINAL_CONTENT_TYPE': 'application/vnd.cups-postscript',
            }

        (stdin_r,  stdin_w)  = os.pipe()
        (stdout_r, stdout_w) = os.pipe()
        (stderr_r, stderr_w) = os.pipe()
        (bchan_r,  bchan_w)  = os.pipe()

        self._pid = os.fork()
        if self._pid == 0:
            # hook up the pipes
            os.dup2(stdin_r,  0)
            os.dup2(stdout_w, 1)
            os.dup2(stderr_w, 2)
            os.dup2(bchan_r,  3)

            # close all other FDs
            maxfd = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
            if maxfd == resource.RLIM_INFINITY:
                maxfd = 1024
            for fd in range(4, maxfd):
                try:
                    os.close(fd)
                except OSError:
                    pass

            os.execve(monitor_exec, args, env)

        os.close(stdin_r)
        os.close(stdout_w)
        os.close(bchan_r)

        self._chanmap = dict()
        self._stdin  = StringDispatcher(stdin_w, instr, map=self._chanmap)
        self._stdout = BufferDispatcher(stdout_r, map=self._chanmap)
        self._stderr = StderrDispatcher(stderr_r, map=self._chanmap)
        self._bchan  = StringDispatcher(bchan_w, '')

        # asyncore dup()s the FDs passed to its constructors
        # so we need to clean up the originals or the pipes won't close
        os.close(stdin_w)
        os.close(stdout_r)
        os.close(stderr_r)

    def wait(self):
        waitpid = 0
        while waitpid == 0:
            asyncore.loop(0.1, False, self._chanmap, 1)
            (waitpid, status) = os.waitpid(self._pid, os.WNOHANG)

        # stdin may have been closed already
        try:
            self._stdin.close()
        except OSError:
            pass;

        self._bchan.close()

        if status != 0:
            if os.WIFSIGNALED(status):
                raise IOError(
                        'monitor killed by signal %d'
                            % os.WTERMSIG(status)
                    )
            else:
                raise IOError(
                        'monitor exited with status %d'
                            % os.WEXITSTATUS(status)
                    )

    def stdout(self):
        return self._stdout.result()
