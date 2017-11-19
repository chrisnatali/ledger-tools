require 'spec_helper'

module LedgerTools
  include Model
  describe CSV2Ledger do

    let(:date_format) { '%m/%d/%Y' }
    let(:balance_account) { 'Assets:Checking' }

    let(:field_mappings) do
      {
        'date' => 'Date',
        'payee' => 'Transaction Description',
        'account' => ':payee', # lookup against the payee value
        'amount' => 'Amount',
        'transaction_type' => 'Transaction Type'
      }
    end
    let(:payee_mappings) do
      {
        'Amazon' => [/AMZ$/],
        'Ben and Jerrys' => [/BEN JERRY/],
        'Paycheck' => [/PAYCHECK/],
      }
    end
    let(:account_mappings) do
      {
        'Expenses:Dining' => [
            /Ben and Jerrys/,
          ],
        'Income:Salary' => [/Paycheck/],
        'Expenses' => [/.*/] # catch all
      }
    end
    let(:transaction_type_mappings) do 
      { 
        'credit' => [/credit/],
        'debit' => [/.*/] # default
      }
    end
    let(:transaction_type_factor_mapping) do
      {
        'credit' => -1,
        'debit'  => 1
      }
    end
    let(:csv2ledger) do
      LedgerTools::CSV2Ledger.new(
        field_mappings: field_mappings,
        payee_mappings: payee_mappings,
        account_mappings: account_mappings,
        date_format: date_format,
        balance_account: balance_account,
        transaction_type_mappings: transaction_type_mappings,
        transaction_type_factor_mapping: transaction_type_factor_mapping)
    end
    let(:credit_debit_field_mappings) do
      {
        'date' => 'Date',
        'payee' => 'Transaction Description',
        'account' => ':payee', # lookup against the payee value
        'credit_amount' => 'Credit',
        'debit_amount' => 'Debit',
      }
    end
    let(:csv2ledger_credit_debit) do
      LedgerTools::CSV2Ledger.new(
        field_mappings: credit_debit_field_mappings,
        payee_mappings: payee_mappings,
        account_mappings: account_mappings,
        date_format: date_format,
        balance_account: balance_account,
        transaction_type_mappings: transaction_type_mappings,
        transaction_type_factor_mapping: transaction_type_factor_mapping)
    end
    let(:input_csv) do
      <<~EOF
      "Date","Transaction Description","Amount","Transaction Type"
      9/21/2017,B3211 AMZ,23.22,debit
      9/22/2017,123 BEN JERRY HG,3.92,debit
      9/24/2017,ABC TOYS,5.99,debit
      9/27/2017,MY PAYCHECK,900.20,credit
      EOF
    end
    let(:input_csv_credit_debit) do
      <<~EOF
      "Date","Transaction Description","Debit","Credit"
      9/21/2017,B3211 AMZ,23.22,
      9/22/2017,123 BEN JERRY HG,3.92,
      9/24/2017,ABC TOYS,5.99,
      9/27/2017,MY PAYCHECK,,900.20
      EOF
    end

    let(:output_ledger) do
      <<~EOF
      2017-09-21 Amazon
          ;9/21/2017,B3211 AMZ,23.22,debit
          Expenses  $23.22
          Assets:Checking  $-23.22

      2017-09-22 Ben and Jerrys
          ;9/22/2017,123 BEN JERRY HG,3.92,debit
          Expenses:Dining  $3.92
          Assets:Checking  $-3.92

      2017-09-24 ABC TOYS
          ;9/24/2017,ABC TOYS,5.99,debit
          Expenses  $5.99
          Assets:Checking  $-5.99

      2017-09-27 Paycheck
          Assets:Checking  $900.20
          ;9/27/2017,MY PAYCHECK,900.20,credit
          Income:Salary  $-900.20
      EOF
    end

    let(:output_ledger_credit_debit) do
      <<~EOF
      2017-09-21 Amazon
          ;9/21/2017,B3211 AMZ,23.22,
          Expenses  $23.22
          Assets:Checking  $-23.22

      2017-09-22 Ben and Jerrys
          ;9/22/2017,123 BEN JERRY HG,3.92,
          Expenses:Dining  $3.92
          Assets:Checking  $-3.92

      2017-09-24 ABC TOYS
          ;9/24/2017,ABC TOYS,5.99,
          Expenses  $5.99
          Assets:Checking  $-5.99

      2017-09-27 Paycheck
          Assets:Checking  $900.20
          ;9/27/2017,MY PAYCHECK,,900.20
          Income:Salary  $-900.20
      EOF
    end


    # TODO factor out into lib?
    def create_simple_transaction(
      name, date, account, amount, commodity, balance_account, is_credit, memo)
      main = Entry.new(
        account: account,
        amount: Money.new(amount, commodity),
        memo: memo)
      balance = Entry.new(
        account: balance_account,
        amount: Money.new(-amount, commodity))
      entries = is_credit ? [balance, main] : [main, balance]
      Transaction.new(name: name, date: date, entries: entries)
    end

    # Test data added as let vars
    # result will be that the following vars are created for each:
    # "#{key}_txn".to_sym var for txn
    # "#{key}_record".to_sym var for csv record
    {
      amz: {
        txn: ["Amazon", Date.new(2017, 9, 21), "Expenses", 2322, "USD", 
              "Assets:Checking", false],
        csv_row: "9/21/2017,B3211 AMZ,23.22,debit"},
      ben_jerry: {
        txn: ["Ben and Jerrys", Date.new(2017, 9, 22), "Expenses:Dining", 392,
              "USD", "Assets:Checking", false],
        csv_row: "9/22/2017,123 BEN JERRY HG,3.92,debit"},
      abc: {
        txn: ["ABC TOYS", Date.new(2017, 9, 24), "Expenses", 599,
              "USD", "Assets:Checking", false],
        csv_row: "9/24/2017,ABC TOYS,5.99,debit"},
      paycheck: {
        txn: ["Paycheck", Date.new(2017, 9, 27), "Income:Salary", -90020,
              "USD", "Assets:Checking", true],
        csv_row: "9/27/2017,MY PAYCHECK,900.20,credit"},
    }.each do |key, record|
      txn_key = "#{key}_txn".to_sym # e.g. amz_txn
      record_key = "#{key}_record".to_sym # e.g. amz_record
      let(txn_key) { create_simple_transaction(*record[:txn], record[:csv_row]) }
      let(record_key) do
        CSV::Row.new(
          ["Date","Transaction Description","Amount","Transaction Type"],
          record[:csv_row].split(",")
        )
      end
    end

   describe "#record_to_transaction" do
      let(:payee_txn) { amz_txn }
      let(:payee_record) {amz_record} 
      let(:payee_and_account_txn) { ben_jerry_txn }
      let(:payee_and_account_record) { ben_jerry_record }
      let(:credit_txn) { paycheck_txn }
      let(:credit_record) { paycheck_record }
      it "matches payee transaction" do
        actual = csv2ledger.record_to_transaction(payee_record)
        expect(actual).to eq(payee_txn)
      end
      it "matches payee and account transaction" do
        actual = csv2ledger.record_to_transaction(payee_and_account_record)
        expect(actual).to eq(payee_and_account_txn)
      end
      it "matches credit transaction" do
        actual = csv2ledger.record_to_transaction(credit_record)
        expect(actual).to eq(credit_txn)
      end

    end

    describe "#csv_to_transactions" do
      let(:csv_records) do 
        [amz_record, ben_jerry_record, abc_record, paycheck_record]
      end
      let(:transactions) do 
        [amz_txn, ben_jerry_txn, abc_txn, paycheck_txn]
      end
      it "returns matching transactions" do
        actual = csv2ledger.csv_to_transactions(csv_records)
        expect(actual).to eq(transactions) 
      end
    end

    describe "#write_csv_as_ledger" do
      let(:input_io) { StringIO.new(input_csv) }
      let(:output_io) { StringIO.new }
      it "returns matching ledger formatted output" do
        csv2ledger.write_csv_as_ledger(input_io, output_io)
        expect(output_io.string).to eq(output_ledger)
      end
    end

    context "csv contains separate credit and debit fields" do
      describe "#write_csv_as_ledger" do
        let(:input_io) { StringIO.new(input_csv_credit_debit) }
        let(:output_io) { StringIO.new }
        it "returns matching ledger formatted output" do
          csv2ledger_credit_debit.write_csv_as_ledger(input_io, output_io)
          expect(output_io.string).to eq(output_ledger_credit_debit)
        end
      end
    end
  end
end
