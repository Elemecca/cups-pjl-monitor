/* cups-pjl-monitor - CUPS port monitor for HP PJL status reporting
 * Copyright 2016 Sam Hanes <sam@maltera.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>
#include <signal.h>
#include <errno.h>
#include <stdio.h>
#include <cups/cups.h>

static int job_canceled = 0;
static void cancel_job (int sig) {
    job_canceled = 1;
}

#define SET_NONBLOCK(fd) \
    fcntl((fd), F_SETFL, fcntl((fd), F_GETFL) | O_NONBLOCK);

#if PIPE_BUF >= 4096
#  define PRINT_BUF_LEN PIPE_BUF
#else
#  define PRINT_BUF_LEN 8192
#endif

int main (int argc, char *argv[]) {
    int print_fd;
    int device_fd = STDOUT_FILENO;
    int backchannel_fd = CUPS_BC_FD;
    int copies;

    int nfds;
    fd_set readfds, writefds;

    int print_sending = 0;
    char print_buffer[PRINT_BUF_LEN];
    char *print_ptr = print_buffer;
    size_t bytes = 0;
    size_t print_bytes = 0;

    // ensure status messages are not buffered
    setbuf(stderr, NULL);

    // ignore broken pipe signals; the scheduler will handle them
    signal(SIGPIPE, SIG_IGN);

    // register a signal handler to cleanly cancel a job
    signal(SIGTERM, cancel_job);

    // check the command line
    if (argc < 6 || argc > 7) {
        fprintf(stderr,
                "Usage: %s job-id user title copies options [file]\n",
                argv[0]
            );
        return 1;
    }

    // open the input file if necessary
    if (argc == 6) {
        copies = -1;
        print_fd = STDIN_FILENO;
    } else {
        copies = atoi(argv[4]);
        print_fd = open(argv[6], O_RDONLY);
        if (print_fd < 0) {
            fprintf(stderr, "ERROR: Unable to open print file\n");
            return 1;
        }
    }

    fprintf(stderr, "DEBUG: PJL port monitor running.\n");

    SET_NONBLOCK(device_fd)
    SET_NONBLOCK(print_fd)
    SET_NONBLOCK(backchannel_fd)

    // determine the highest FD for select
    nfds = device_fd;
    if (backchannel_fd > nfds)
        nfds = backchannel_fd;
    if (print_fd > nfds)
        nfds = print_fd;

    print_sending = 1;
    while (print_sending || print_bytes > 0) {
        FD_ZERO(&readfds);
        FD_ZERO(&writefds);

        // always resume when backchannel data is available to read
//        FD_SET(backchannel_fd, &readfds);

        // resume when print data is available to read
        // only if we want data and the buffer is empty
        if (print_sending && print_bytes == 0)
            FD_SET(print_fd, &readfds);

        // resume when data can be written
        // only if we have data in the buffer
        if (print_bytes > 0)
            FD_SET(device_fd, &writefds);


        // block until we can do something
        if (select(nfds, &readfds, &writefds, NULL, NULL) < 0) {
            // select error
            // bail immediately unless the error is transient
            if (errno != EINTR) {
                fprintf(stderr,
                        "DEBUG: select failed: %s\n",
                        strerror(errno)
                    );
                fprintf(stderr, "ERROR: Unable to read print data.\n");
                return 1;
            }
        }


        // process backchannel data, if any is available
//        if (FD_ISSET(backchannel_fd, &readfds)) {
//            // TODO: handle backchannel data
//        }


        // read print data into the buffer
        if (print_bytes == 0 && FD_ISSET(print_fd, &readfds)) {
            bytes = read(print_fd, print_buffer, sizeof(print_buffer));
            if (bytes < 0) {
                // read error
                // bail immediately unless the error is transient
                if (errno != EAGAIN && errno != EINTR) {
                    fprintf(stderr,
                            "DEBUG: read failed: %s\n",
                            strerror(errno)
                        );
                    fprintf(stderr, "ERROR: Unable to read print data.\n");
                    return 1;
                }
            } else if (bytes == 0) {
                // end of file
                if (--copies > 0) {
                    // we have more copies to print
                    // seek back to the beginning of the input
                    if (lseek(print_fd, 0, SEEK_SET) < 0) {
                        fprintf(stderr,
                                "DEBUG: seek for copies failed: %s\n",
                                strerror(errno)
                            );
                        fprintf(stderr, "ERROR: Unable to read print data.\n");
                        return 1;
                    }
                } else {
                    // we're out of copies (or reading from a pipe)
                    print_sending = 0;
                }
            } else {
                // all good - get the buffer ready to write
                print_bytes = bytes;
                print_ptr = print_buffer;
            }
        }


        // write print data from the buffer
        // we don't care if device_fd was selected:
        //   if we can't write yet write() will just return immediately
        if (print_bytes > 0) {
            bytes = write(device_fd, print_ptr, print_bytes);
            if (bytes < 0) {
                // write error
                // bail immediately unless the error is transient
                if (errno != EAGAIN && errno != EINTR) {
                    fprintf(stderr,
                            "DEBUG: write failed: %s\n",
                            strerror(errno)
                        );
                    fprintf(stderr, "ERROR: Unable to write print data.\n");
                    return 1;
                }
            } else {
                // all good - update buffer state
                print_bytes -= bytes;
                print_ptr += bytes;
            }
        }
    }

    return 0;
}
