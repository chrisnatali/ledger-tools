"""
Translate QIF file into Ledger file

QIF Files Represent transactions with entries from many "target"
accounts that apply to a single "source" account (an asset account)
"""

import argparse
import datetime
import mmap
import re
from qif_parser import QIFParser

def ledger_account_name(name):
    """
    ensure account complies with ledger format
    """
    # replace 'hard separators' in the name
    pattern = re.compile(r'[ ]{2,}|[\t]')
    return pattern.sub(" ", name)

def ledger_amount(amount):
    """
    Convert amount to ledger format from QIF

    An amount in QIF is in "source" account terms which is implied
    to be an asset account

    We need to negate the amount to apply it to the "target" account
    
    e.g. Expenses:Tax would be negative in QIF (as it subtracts directly 
    from the asset account).  But it's a positive in Ledger as it adds to
    the Tax account and subtracts from the asset account
    """
    if amount != 0.0:
       return -amount
    else:
        return amount

  
def qif2ledger(qif_transaction, asset_account):
    """
    return a dict with ledger attributes suitable for 
    use in writing a ledger file
    """

    l = {}
    postings = []
    for r in qif_transaction.records:
        d = r.value_dict
        if r.type == 'DATE':
            l['date'] = d['date'].strftime("%Y/%m/%d")
        if r.type == 'PAYEE':
            l['payee'] = d['value']
        if r.type in ['U_AMOUNT', 'T_AMOUNT']:
            amount = ledger_amount(d['amount'])
        if r.type == 'CATEGORY':
            account = ledger_account_name(d['value'])
        if r.type == 'MEMO':
            l['memo'] = d['value']
        if r.type == 'SPLIT':
            posting = {
                'account': ledger_account_name(d['category']),
                'amount': ledger_amount(d['amount'])
            }
            if 'memo' in d:
                posting['memo'] = d['memo']
            postings.append(posting)
    
    if len(postings) == 0:
        posting = {
            'account': ledger_account_name(account),
            'amount': ledger_amount(amount)
        }
        postings.append(posting)

    postings.append({'account': asset_account})
    l['postings'] = postings
    return l
    
def print_ledger_dict(d):
    MEMO_TEMPLATE = "    ;{memo}"
    SPLIT_TEMPLATE = "    {account}  ${amount}"""
    SPLIT_TEMPLATE_MEMO = "    {account}  ${amount}  ;{memo}"""
    SPLIT_TEMPLATE_MEMO_NO_AMOUNT = "    {account}  ;{memo}"""
    SPLIT_TEMPLATE_NO_AMOUNT = "    {account}"""
    
    print("{date} {payee}".format(**d))
    if 'memo' in d:
        print(MEMO_TEMPLATE.format(**d))

    for p in d['postings']:
        if 'memo' in p:
            if 'amount' in p:
                print(SPLIT_TEMPLATE_MEMO.format(**p))
            else:
                print(SPLIT_TEMPLATE_MEMO_NO_AMOUNT.format(**p))
        elif 'amount' in p:
            print(SPLIT_TEMPLATE.format(**p))
        else: 
            print(SPLIT_TEMPLATE_NO_AMOUNT.format(**p))

    print("")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Translate QIF to ledger")
    parser.add_argument("-a", "--asset_account", help="Account transactions apply to")
    parser.add_argument("qif", help="QIF filename to be parsed")

    args = parser.parse_args()

    with open(args.qif, 'r', encoding="utf-8") as f: 
        text_map = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        qif_parser = QIFParser()
        for transaction in qif_parser.parse(text_map):
            # TODO:  Output more useful format
            ledger_dict = qif2ledger(transaction, args.asset_account)
            print_ledger_dict(ledger_dict)
        text_map.close()
