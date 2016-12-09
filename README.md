# Ledger Tools

Tools for maintaining double entry accounting data in [ledger](ledger-cli.org) format.  

See also [plaintextaccounting.org](plaintextaccounting.org)

## Usage

### qif2ledger

Use to migrate Quicken data to Ledger format

Steps:
- Export each quicken account as a QIF
- Run them through qif2ledger to create a ledger formatted file
- [optional] Find/replace categories with appropriate account names
  I use the prefixes suggested in the ledger-cli doc (Assets, Expenses, Liabilities, Income, Equity)

Example using sample QIF file provided:

```
python qif2ledger.py -a Assets:Checking sample.qif > ledger_sample.dat
```

You can then run register or balance reports via ledger:

```
ledger -f ledger_sample.dat register
```

## Testing

Run nosetests
