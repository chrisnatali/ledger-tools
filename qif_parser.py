"""
Module for parsing Quicken Interchange Format (QIF) files 
into transaction tuples

See:  https://en.wikipedia.org/wiki/Quicken_Interchange_Format
"""

import re
import collections
import copy
import datetime


""" 
Transaction Record Syntax 

Define record types using named groups (to be referenced when processing later) 
"""

HEADER = br'(?P<HEADER>!Type(?P<type>.*))[\r]?$'
DATE = br'(?P<DATE>D(?P<month>[ 01]?[\d])/(?P<day>[ 0123][\d])((\'(?P<year_short>[ ]?\d[\d]?))|(/(?P<year_long>[\d]{4}))))[\r]?$' #noqa
T_AMOUNT = br'(?P<T_AMOUNT>T(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$'
U_AMOUNT = br'(?P<U_AMOUNT>U(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$'
CLEARED = br'(?P<CLEARED>C(?P<value>[\*cXR]))[\r]?$'
PAYEE = br'(?P<PAYEE>P(?P<value>.*))[\r]?$'
MEMO = br'(?P<MEMO>M(?P<value>.*))[\r]?$'
CATEGORY = br'(?P<CATEGORY>L(?P<value>.*))[\r]?$'
ADDRESS = br'(?P<ADDRESS>A(?P<value>.*))[\r]?$'
N_REC = br'(?P<N_REC>N(?P<value>.*))[\r]?$' # different interp for investments
SPLIT = br'(?P<SPLIT>S(?P<category>.*)[\r]?\n(?:E(?P<memo>.*)[\r]?\n)?\$(?P<amount>-?[\d,]+(\.[\d]+)?))[\r]?$' #noqa
END = br'(?P<END>\^)[\r]?$'

TTYPE_NORMAL = 'NORMAL'
TTYPE_SPLIT = 'SPLIT'

QIFRecord = collections.namedtuple('QIFRecord', ['type', 'value_dict'])
QIFTransaction = collections.namedtuple('Transaction', ['type', 'records'])

_qif_record_regexes = [
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
_compiled_record_regexes = [re.compile(regex, re.M) for regex in _qif_record_regexes]

def _cast_date(record):
    d = record.value_dict
    month = int(d['month'])
    day = int(d['day'])
    if 'year_short' in d and d['year_short'] is not None:
        # short year is only 1 or 2 digits, so it represents a 50 year period
        year = int(d['year_short'])
        if year <= 50:
            year += 2000
        elif year > 50:
            year += 1900
    else:
        year = int(d['year_long'])

    date_val = datetime.date(year, month, day)

    return QIFRecord(record.type, {'date': date_val})

def _cast_amount(record):
    d = record.value_dict
    sub_dict = {
        'amount': float(d['amount'].replace(",", ""))
    }
    return QIFRecord(record.type, sub_dict)

def _cast_split(record):
    d = record.value_dict
    sub_dict = {
        'category': d['category'],
        'amount': float(d['amount'].replace(",", ""))
    }
    if 'memo' in d and d['memo'] is not None:
        sub_dict['memo'] = d['memo']

    return QIFRecord(record.type, sub_dict)

def _cast_general(record):
    return QIFRecord(record.type, {'value': record.value_dict['value']})

_record_casts = {
    'DATE': _cast_date,
    'T_AMOUNT': _cast_amount,
    'U_AMOUNT': _cast_amount,
    'CLEARED': _cast_general,
    'PAYEE': _cast_general,
    'MEMO': _cast_general,
    'CATEGORY': _cast_general,
    'ADDRESS': _cast_general,
    'N_REC': _cast_general,
    'SPLIT': _cast_split
}

class QIFParser:

    def _recordize(self, text):
        """
        iterator of QIFRecords as scanned
        QIFRecords are raw, except that byte-likes are converted to strings
        """

        def decode_val(val):
            if val is not None and not isinstance(val, str):
                return val.decode('utf-8')
            else:
                return val

        position = 0
        while True:
            record = None
            for record_regex in _compiled_record_regexes:
                # yield first match found
                m = record_regex.match(text, position)
                if m is not None:
                    position = m.span()[1] + 1
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
        parse QIFRecords and yield transaction tuples

        text can be either a bytes object or a string

        QIFRecords within transactions are converted to standard types
        where appropriate (i.e. amount strings -> floats)
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
            
            if r.type in _record_casts:
                records.append(_record_casts[r.type](r))
            else:
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
