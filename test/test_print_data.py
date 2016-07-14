#!/usr/bin/env python

import os, sys
import asyncore
import resource
import unittest

class StringDispatcher(asyncore.file_dispatcher):
    def __init__(self, fd, string):
        asyncore.file_dispatcher.__init__(self, fd)
        self.buffer = string

    def handle_write(self):
        sent = self.send(self.buffer)

        self.buffer = self.buffer[sent:]
        if len(self.buffer) == 0:
            self.close()

class BufferDispatcher(asyncore.file_dispatcher):
    def __init__(self, fd):
        asyncore.file_dispatcher.__init__(self, fd)
        self.buffer = bytearray()

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

    def handle_read(self):
        sys.stderr.write(self.recv(4096))


class TestPrintData(unittest.TestCase):
    longMessage = True

    @classmethod
    def setUpClass(cls):
        super(TestPrintData, cls).setUpClass()

        cls.monitor_exec = os.getenv('TEST_MONITOR_EXEC')
        if cls.monitor_exec is None:
            raise IOError('TEXT_MONITOR_EXEC is not set')
        if not os.path.isfile(cls.monitor_exec):
            raise IOError('TEST_MONITOR_EXEC file not found')



    def test_stdin_through(self):
        # test with a random 64k binary string
        # this ought to be bigger than the transfer buffer
        instr = bytearray(os.urandom(64*1024))

        device_uri = 'socket://printer:9100'
        args = [ device_uri, '1', 'lpr', 'test-job', '1', '' ]
        env = {
                'DEVICE_URI': device_uri,
                'PRINTER': 'test-printer',
                'FINAL_CONTENT_TYPE': 'application/vnd.cups-postscript',
            }

        (stdin_r,  stdin_w)  = os.pipe()
        (stdout_r, stdout_w) = os.pipe()
        (stderr_r, stderr_w) = os.pipe()
        (bchan_r,  bchan_w)  = os.pipe()

        sys.stderr.write("this is on stderr");

        pid = os.fork()
        if pid == 0:
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

            os.execve(self.monitor_exec, args, env)

        os.close(stdin_r)
        os.close(stdout_w)
        os.close(bchan_r)

        stdin  = StringDispatcher(stdin_w, instr)
        stdout = BufferDispatcher(stdout_r)
        stderr = StderrDispatcher(stderr_r)
        #bchan  = StringDispatcher(bchan_w, '')

        # asyncore dup()s the FDs passed to its constructors
        # so we need to clean up the originals or the pipes won't close
        os.close(stdin_w)
        os.close(stdout_r)
        os.close(stderr_r)

        waitpid = 0
        while waitpid == 0:
            asyncore.loop(0.1, None, None, 1)
            (waitpid, status) = os.waitpid(pid, os.WNOHANG)

        # stdin may have been closed already
        try:
            stdin.close()
        except OSError:
            pass;

        os.close(bchan_w)
        # stdout and stderr are already closed

        if status != 0:
            if os.WIFSIGNALED(status):
                self.fail(msg =
                        'monitor killed by signal %d'
                            % os.WTERMSIG(status)
                    )
            else:
                self.fail(msg =
                        'monitor exited with status %d'
                            % os.WEXITSTATUS(status)
                    )

        self.assertEqual(stdout.result(), instr,
                msg='stdout does not match stdin'
            )
