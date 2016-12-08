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
HEADER = br'(?P<HEADER>!Type(?P<type>.*))[\r]?$'
DATE = br'(?P<DATE>D(?P<month>[ 01]?[\d])/(?P<day>[ 0123][\d])\'(?P<year>[ \d][\d]))[\r]?$'
T_AMOUNT = br'(?P<T_AMOUNT>T(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$'
U_AMOUNT = br'(?P<U_AMOUNT>U(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$'
CLEARED = br'(?P<CLEARED>C(?P<value>[\*cXR]))[\r]?$'
PAYEE = br'(?P<PAYEE>P(?P<value>.*))[\r]?$'
MEMO = br'(?P<MEMO>M(?P<value>.*))[\r]?$'
CATEGORY = br'(?P<CATEGORY>L(?P<value>.*))[\r]?$'
ADDRESS = br'(?P<ADDRESS>A(?P<value>.*))[\r]?$'
N_REC = br'(?P<N_REC>N(?P<value>.*))[\r]?$' # different interp for investments
SPLIT = br'(?P<SPLIT>S(?P<category>.*)[\r]?\n(?:(?P<memo>E.*)[\r]?\n)?\$(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$'
END = br'(?P<END>\^)[\r]?$'

TTYPE_NORMAL = 'NORMAL'
TTYPE_SPLIT = 'SPLIT'

QIFRecord = collections.namedtuple('QIFRecord', ['type', 'value_dict'])
QIFTransaction = collections.namedtuple('Transaction', ['type', 'records'])
qif_record_regexes = [
    HEADER,
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

        def decode_val(val):
            if val is not None and not isinstance(val, str):
                return val.decode('utf-8')
            else:
                return val

        position = 0
        while True:
            record = None
            for record_regex in compiled_record_regexes:
                # yield first match found
                m = record_regex.match(text, position)
                if m is not None:
                    position = m.span()[1] + 1
                    print("{}, {}".format(m.groupdict(), type(m.groupdict())))
                    
                    decoded_dict = {
                        k: decode_val(v) for k, v in m.groupdict().items()
                    }
                    record = QIFRecord(m.lastgroup, decoded_dict)
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

        text can be either a bytes object or a string
        """

        ttype = TTYPE_NORMAL
        records = []

        # Handle string input...internally, we parse by bytes
        if (isinstance(text, str)):
            text = text.encode('utf-8')

        for r in self._recordize(text):
            if r.type == 'END':
                transaction = QIFTransaction(ttype, copy.deepcopy(records))
                ttype = TTYPE_NORMAL
                records = []
                yield transaction
                continue #skip appending 'END'

            elif r.type == 'SPLIT':
                ttype = TTYPE_SPLIT

            records.append(r)
               

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
        text_map.close()
