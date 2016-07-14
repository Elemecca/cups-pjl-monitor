
import os
import difflib

class TestCaseHelper(object):
    def __init__(self, *args, **kwargs):
        super(TestCaseHelper, self).__init__(*args, **kwargs)
        self.addTypeEqualityFunc(bytearray, 'assertBinaryEqual')

    def assertBinaryEqual(self, seq1, seq2, msg=None):
        if not isinstance(seq1, bytearray):
            raise self.failureException('First argument is not a bytearray')
        if not isinstance(seq2, bytearray):
            raise self.failureException('Second argument is not a bytearray')

        if seq1 == seq2:
            return

        # sequences don't match, use difflib to get an edit list
        matcher = difflib.SequenceMatcher(autojunk=False)
        matcher.set_seqs(seq1, seq2)
        edits = matcher.get_opcodes()


        def hexlify(seq):
            return ' '.join("%02x" % b for b in seq)

        count = 1
        result = 'bytearrays differ:\n'
        for tag, i1, i2, j1, j2 in edits:
            count1 = i2 - i1
            count2 = j2 - j1

            if 'equal' == tag:
                continue

            if 'insert' == tag:
                result += '  at %d insert %d' % (j1, count2)
                if count2 > 16:
                    result += ' (too many to show)\n'
                else :
                    result += ': ' + hexlify(seq2[j1:j2]) + '\n'

            elif 'delete' == tag:
                result += '  at %d delete %d' % (i1, count1)
                if count1 > 16:
                    result += ' (too many to show)\n'
                else:
                    result += ': ' + hexlify(seq1[i1:i2]) + '\n'

            elif 'replace' == tag:
                result += (
                        '  at %d replace %d with %d:\n    -%s%s\n    +%s%s\n'
                    ) % (
                        count1, count2,
                        hexlify(seq1[i1:(i2 + 16 - count1)]),
                        (' ...' if count1 > 16 else ''),
                        hexlify(seq2[j1:(j2 + 16 - count2)]),
                        (' ...' if count2 > 16 else '')
                    )

            count += 1
            if count > 16:
                result += '  (%d changes, showing first 16)\n' % len(edits)
                break

        if msg is not None:
            result += msg

        raise self.failureException(result)
