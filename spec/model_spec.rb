require 'ledger_tools'

include LedgerTools
include LedgerTools::Model

describe Model do

  let(:account) { Account.new(name: "Income:Salary") }
  let(:entry_salary) do 
    Entry.new(
      account: "Income:Salary",
      amount: Money.new(-1000_00, "USD"), 
      memo: "paycheck 1") 
  end
  let(:entry_deposit) do 
    Entry.new(
      account: "Assets:Checking",
      amount: Money.new(1000_00, "USD")) 
  end
  let(:transaction) do
    Transaction.new(
      name: "Employer Payment",
      date: Date.new(2017, 1, 3),
      entries: [entry_salary, entry_deposit])
  end

  describe Account do
    it "has a name" do
      expect(account.name).to eq("Income:Salary")
    end
  end

  describe Entry do
    describe "#to_ledger" do
      it "formats correctly" do
        expect(entry_salary.to_ledger_string).to eq("    Income:Salary  $-1,000.00;paycheck 1")
        expect(entry_deposit.to_ledger_string).to eq("    Assets:Checking  $1,000.00")
      end
    end
  end

  describe Transaction do
    describe "#to_ledger" do
      transaction_text = <<~EOF
      2017-01-03 Employer Payment
          Income:Salary  $-1,000.00;paycheck 1
          Assets:Checking  $1,000.00
      EOF
      it "formats correctly" do
        expect(transaction.to_ledger_string).to eq(transaction_text)
      end
    end

    describe "#==" do
      let(:transaction_compare) do
        Transaction.new(
          name: "Employer Payment",
          date: Date.new(2017, 1, 3),
          entries: [entry_salary, entry_deposit])
      end
      it "returns true when attributes are equal" do
        expect(transaction).to eq(transaction_compare)
      end
      it "returns false when attributes are not equal" do
        transaction_compare.name = "Something Else"
        expect(transaction).not_to eq(transaction_compare)
      end
    end
  end
end
