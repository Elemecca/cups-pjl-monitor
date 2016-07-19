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
#include <stdint.h>
#include <fcntl.h>
#include <sys/select.h>
#include <signal.h>
#include <errno.h>
#include <stdio.h>
#include <cups/cups.h>

#include "status.h"
#include "status.yy.h"

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

#define UEL "\033%-12345X"


void yyerror (status_report_t *status, const char const *msg) {
    fprintf(stderr, "DEBUG: pjl: status parser error: %s\n", msg);
}

int main (int argc, char *argv[]) {
    int print_fd;
    int device_fd = STDOUT_FILENO;
    int status_fd = CUPS_BC_FD;
    int copies;

    int result;

    int nfds;
    fd_set readfds, writefds;
    size_t bytes = 0;

    int print_sending = 0;
    uint8_t print_buffer[PRINT_BUF_LEN];
    uint8_t *print_ptr = print_buffer;
    size_t print_bytes = 0;

    uint8_t status_buffer[PRINT_BUF_LEN];
    uint8_t *status_ptr = status_buffer;
    size_t status_bytes = 0;

    yypstate *parser;
    status_report_t status;
    int input_char;
    YYSTYPE input_val;


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

    parser = yypstate_new();
    if (NULL == parser) {
        fprintf(stderr, "DEBUG: pjl: error initializing status parser\n");
        fprintf(stderr, "ERROR: internal error in PJL filter\n");
        return 1;
    }

    fprintf(stderr, "DEBUG: PJL port monitor running.\n");

    SET_NONBLOCK(device_fd)
    SET_NONBLOCK(print_fd)
    SET_NONBLOCK(status_fd)

    // determine the highest FD for select
    nfds = device_fd;
    if (status_fd > nfds)
        nfds = status_fd;
    if (print_fd > nfds)
        nfds = print_fd;
    nfds++; // nfds is a count, not an index

    print_sending = 1;
    while (print_sending || print_bytes > 0) {
        FD_ZERO(&readfds);
        FD_ZERO(&writefds);

        // always resume when status data is available to read
        FD_SET(status_fd, &readfds);

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
                        "DEBUG: pjl: select failed: %s\n",
                        strerror(errno)
                    );
                fprintf(stderr, "ERROR: Unable to read print data.\n");
                return 1;
            }
        }


        // read status data, if any is available
        if (status_bytes == 0 && FD_ISSET(status_fd, &readfds)) {
            bytes = read(status_fd, status_buffer, sizeof(status_buffer));
            if (bytes < 0) {
                // read error
                if (errno == EAGAIN || errno == EINTR) {
                    // error is transient - try again
                    // we want to read status before sending more print data
                    continue;
                } else {
                    // error is permanent - bail immediately
                    fprintf(stderr,
                            "DEBUG: pjl: status read failed: %s\n",
                            strerror(errno)
                        );
                    fprintf(stderr, "ERROR: Unable to read status data.\n");
                    return 1;
                }
            } else if (bytes == 0) {
                // end of file - bail immediately
                fprintf(stderr, "DEBUG: pjl: backchannel reached EOF\n");
                fprintf(stderr, "ERROR: Unable to read status data.\n");
                return 1;
            } else {
                // all good - get the buffer ready to parse
#             ifdef DEBUG
                fprintf(stderr, "DEBUG2: pjl: read %d status bytes\n", bytes);
#             endif
                status_bytes = bytes;
                status_ptr = status_buffer;
            }
        }


        // parse status data if any is in the buffer
        for (; status_bytes > 0; status_ptr++, status_bytes--) {
            input_char = *status_ptr;
            input_val.character = input_char;

            if (input_char > '~') {
                // Roman-8 characters that don't map to ASCII
                input_char = TOK_CHAR;
            } else if (input_char < '\t' || input_char == '\v') {
                // control characters not used in grammar rules
                input_char = TOK_CTL;
            }

            result = yypush_parse( parser, input_char, &input_val, &status );
            if (result != YYPUSH_MORE) {
                fprintf(stderr,
                        "DEBUG: pjl: status parser returned %d\n",
                        result
                    );
                fprintf(stderr, "ERROR: internal error in PJL filter\n");
                return 1;
            }

            switch (status.type) {
            case STYPE_NONE:
                // the parser needs more input
                continue;
            }
        }


        // read print data into the buffer
        // we don't care if print_fd was selected:
        //   if we can't read yet read() will just return immediately
        if (print_bytes == 0 && print_sending) {
            bytes = read(print_fd, print_buffer, sizeof(print_buffer));
            if (bytes < 0) {
                // read error
                // bail immediately unless the error is transient
                if (errno != EAGAIN && errno != EINTR) {
                    fprintf(stderr,
                            "DEBUG: pjl: print read failed: %s\n",
                            strerror(errno)
                        );
                    fprintf(stderr, "ERROR: Unable to read print data.\n");
                    return 1;
                }
            } else if (bytes == 0) {
                // end of file
                if (--copies > 0) {
                    fprintf(stderr, "DEBUG: seeking for next copy\n");
                    // we have more copies to print
                    // seek back to the beginning of the input
                    if (lseek(print_fd, 0, SEEK_SET) < 0) {
                        fprintf(stderr,
                                "DEBUG: pjl: seek for copies failed: %s\n",
                                strerror(errno)
                            );
                        fprintf(stderr, "ERROR: Unable to read print data.\n");
                        return 1;
                    }
                } else {
                    // we're out of copies (or reading from a pipe)
                    fprintf(stderr, "DEBUG: pjl: done reading print data\n");
                    print_sending = 0;
                }
            } else {
                // all good - get the buffer ready to write
#             ifdef DEBUG
                fprintf(stderr, "DEBUG2: pjl: read %d print bytes\n", bytes);
#             endif
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
                            "DEBUG: pjl: write failed: %s\n",
                            strerror(errno)
                        );
                    fprintf(stderr, "ERROR: Unable to write print data.\n");
                    return 1;
                }
            } else {
                // all good - update buffer state
#             ifdef DEBUG
                fprintf(stderr, "DEBUG2: pjl: wrote %d print bytes\n", bytes);
#             endif
                print_bytes -= bytes;
                print_ptr += bytes;
            }
        }
    }

    return 0;
}
