#!/usr/bin/env python

import os, sys
import tempfile
import unittest

from helpers.monitor import Monitor

class TestPrintData(unittest.TestCase):

    def test_stdin_through(self):
        # test with a random 64k binary string
        # this ought to be bigger than the transfer buffer
        instr = bytearray(os.urandom(64*1024))

        monitor = Monitor(instr=instr)
        monitor.wait()

        self.assertEqual(monitor.stdout(), instr,
                msg='stdout does not match stdin'
            )

    def test_file_through(self):
        # test with a random 64k binary string
        # this ought to be bigger than the transfer buffer
        instr = bytearray(os.urandom(64*1024))

        temp = tempfile.NamedTemporaryFile()
        temp.write(instr)
        temp.flush()

        monitor = Monitor(infile=temp.name)
        monitor.wait()

        self.assertEqual(monitor.stdout(), instr,
                msg='stdout does not match stdin'
            )
