"""
Module for parsing Quicken Interchange Format (QIF) files 
into transaction tuples
"""

import re
import collections
import copy

""" 
Transaction Record Syntax 

Define record types using named groups (to be referenced when processing later) 
"""

#TODO:  Can byte-like handle utf-8 characters?
DATE = br'(?P<DATE>D(?P<month>[ 01]?[\d])/(?P<day>[ 0123][\d])\'(?P<year>[ \d][\d]))$'
T_AMOUNT = br'(?P<T_AMOUNT>T(?P<amount>-?[\d,]+(\.[\d]+)?))$'
U_AMOUNT = br'(?P<U_AMOUNT>U(?P<amount>-?[\d,]+(\.[\d]+)?))$'
CLEARED = br'(?P<CLEARED>C(?P<value>[\*cXR]))$'
PAYEE = br'(?P<PAYEE>P(?P<value>.*))$'
MEMO = br'(?P<MEMO>M(?P<value>.*))$'
CATEGORY = br'(?P<CATEGORY>L(?P<value>.*))$'
ADDRESS = br'(?P<ADDRESS>L(?P<value>.*))$'
N_REC = br'(?P<N_REC>N(?P<value>.*))$' # different interp for investments
SPLIT = br'(?P<SPLIT>S(?P<category>.*)$\$(?P<amount>-?[\d,]+(\.[\d]+)?))$'
END = br'(?P<END>\^)$'

TTYPE_NORMAL = 'NORMAL'
TTYPE_SPLIT = 'SPLIT'

QIFRecord = collections.namedtuple('QIFRecord', ['type', 'value_dict'])
QIFTransaction = collections.namedtuple('Transaction', ['type', 'records'])
qif_record_regexes = [
    DATE,
    T_AMOUNT,
    U_AMOUNT, 
    CLEARED,
    PAYEE,
    MEMO,
    CATEGORY,
    ADDRESS,
    N_REC,
    SPLIT,
    END
]

# need to allow multi-line regexes (the 're.M') due to Split records
compiled_record_regexes = [re.compile(regex, re.M) for regex in qif_record_regexes]

class QIFParser:

    def _recordize(self, text):
        """
        iterator of QIF records as scanned
        """
        position = 0
        while True:
            record = None
            for record_regex in compiled_record_regexes:
                # yield first match found
                m = record_regex.match(text, position)
                if m is not None:
                    position = m.span()[1] + 1
                    record = QIFRecord(m.lastgroup, m.groupdict())
                    break
            if record is not None:
                yield record
            else:
                if position < len(text):
                    msg = "Error at position {}, {}".format(
                        position,
                        text[position:])
                    raise SyntaxError(msg)
                else:
                    break


    def parse(self, text):
        """
        parse QIF records and yield transaction tuples
        """

        ttype = TTYPE_NORMAL
        records = []
        for r in self._recordize(text):
            if r.type == 'END':
               transaction = QIFTransaction(ttype, copy.deepcopy(records))
               records = []
               yield transaction

            elif r.type == 'SPLIT':
                ttype = TTYPE_SPLIT

            records.append(r)
               
def test_qif_parser():
    # TODO:  Move to tests
    good_qif = "D11/ 8'16\nU-107.88\nT-107.88\nPVERIZON\nLUtilities\n^\nD11/ 9'16\nU-1,570.73\nPChecking\nLVisa\n^" # noqa
    qif_parser = QIFParser()
    for t in qif_parser.parse(good_qif):
        assert(len(t.records) > 1)    

    bad_qif = "D11/ 8'16\nU-107.88\nT-107.88\nPVERIZON\nQ^\nZ^" # no_qa

    try:
        for t in qif_parser.parse(bad_qif):
            assert(False)
    except SyntaxError as e:
        assert("{}".format(e).find("Q^") != -1)
 
if __name__ == '__main__':
    import argparse
    import mmap
    parser = argparse.ArgumentParser(description="Parse Quicken Interchange Format (QIF) file")
    parser.add_argument("qif", help="QIF filename to be parsed")

    args = parser.parse_args()

    with open(args.qif, 'r', encoding="utf-8") as f: 
        text_map = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        qif_parser = QIFParser()
        transaction_num = 0
        for transaction in qif_parser.parse(text_map):
            # TODO:  Output more useful format
            print("T{}".format(transaction_num))
            for record in transaction.records:
                print("    {},{}".format(record.type, record.value_dict))

            transaction_num += 1
