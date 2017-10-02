# Ledger Tools

Tools for maintaining double entry accounting data in [ledger](ledger-cli.org) format.  

See also [plaintextaccounting.org](plaintextaccounting.org)

## Usage

The output of any of the `2ledger` commands should be usable with ledger
for register, balance reports

### qif2ledger

Use to migrate Quicken data to Ledger format

Steps:
- Export each quicken account as a QIF
- Run them through qif2ledger to create a ledger formatted file
- [optional] Find/replace categories with appropriate account names
  I use the prefixes suggested in the ledger-cli doc (Assets, Expenses, Liabilities, Income, Equity)

Example using sample QIF file provided:

```
> cat sample.qif | bundle exec ./bin/qif2ledger Assets:Checking
2005-06-19 Opening Balance
    Equity  $3,134.00
    Assets:Checking  $-3,134.00

2005-06-19 My Am I University
    ;Discrete Math Dropped Reimb
    Education:Tuition  $-3,184.00
    Assets:Checking  $3,184.00

2005-06-19 Tech Software, LLC
    ;Parking in São Paulo
    Reimbursement:Work Expenses  $175.00
    Assets:Checking  $-175.00

```

### csv2ledger

Use to import CSV data to Ledger format

Steps:
- Retrieve and examine your csv file from your bank or other source
- Setup your config file (see csv2ledger_config.yaml for example)
- Run through csv2ledger to create a ledger formatted file

Example using sample CSV file (Mint CSV format) provided:

```
> cat sample.csv | bundle exec ./bin/csv2ledger --config csv2ledger_config.yaml
2017-09-20 Quinnderellas
    ;CSV: 9/20/2017,Quinnderellas,Debit Card Purchase - QUINNDEREL,05.02,debit,Toys,Unnamed Account,"",""
    Expenses  $5.02
    Assets:Checking  $-5.02

2017-09-20 Qdoba
    ;CSV: 9/20/2017,Qdoba Mexican Grill,Debit Card Purchase - QDOBA,20.49,debit,Fast Food,Unnamed Account,"",""
    Expenses:Dining  $20.49
    Assets:Checking  $-20.49

2017-09-26 Debit Card Purchase - CHIPOTLE A
    ;CSV: 9/26/2017,Chipotle,Debit Card Purchase - CHIPOTLE A,22.55,debit,Fast Food,Unnamed Account,"",""
    Expenses  $22.55
    Assets:Checking  $-22.55

2017-09-21 Debit Card Purchase - SQ EMPIRE
    ;CSV: 9/21/2017,Sq Empire,Debit Card Purchase - SQ EMPIRE,9.10,debit,Coffee Shops,Unnamed Account,"",""
    Expenses  $9.10
    Assets:Checking  $-9.10

2017-09-21 Ben and Jerrys
    ;CSV: 9/21/2017,Ben Jerry,Debit Card Purchase - BEN JERRY,10.55,debit,Fast Food,Unnamed Account,"",""
    Expenses:Dining  $10.55
    Assets:Checking  $-10.55

2017-09-21 Seamless
    ;CSV: 9/21/2017,GrubHub Seamless,Debit Card Purchase - SEAMLSSBAR,32.64,debit,Food & Dining,Unnamed Account,"",""
    Expenses:Dining  $32.64
    Assets:Checking  $-32.64
```

## Testing

Run rspec for ruby code

Run nosetests for python code (moving away from)
