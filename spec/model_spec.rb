require 'spec_helper'

module LedgerTools
  describe Model do

    let(:account) { Model::Account.new(name: "Income:Salary") }
    let(:entry_salary) do 
      Model::Entry.new(
        account: "Income:Salary",
        amount: Money.new(-1000_00, "USD"))
    end
    let(:entry_deposit) do 
      Model::Entry.new(
        account: "Assets:Checking",
        amount: Money.new(1000_00, "USD")) 
    end
    let(:transaction) do
      Model::Transaction.new(
        name: "Employer Payment",
        date: Date.new(2017, 1, 3),
        entries: [entry_salary, entry_deposit],
        memo: "paycheck 1") 
    end

    describe Model::Account do
      it "has a name" do
        expect(account.name).to eq("Income:Salary")
      end
    end

    describe Model::Entry do
      describe "#to_ledger" do
        it "formats correctly" do
          expect(entry_salary.to_ledger_string).to eq(
            "    Income:Salary  $-1,000.00")
          expect(entry_deposit.to_ledger_string).to eq(
          "    Assets:Checking  $1,000.00")
        end
      end
    end

    describe Model::Transaction do
      describe "#to_ledger" do
        transaction_text = <<~EOF
        2017-01-03 Employer Payment
            ;paycheck 1
            Income:Salary  $-1,000.00
            Assets:Checking  $1,000.00
        EOF
        it "formats correctly" do
          expect(transaction.to_ledger_string).to eq(transaction_text)
        end
      end

      describe "#==" do
        let(:transaction_compare) do
          Model::Transaction.new(
            name: "Employer Payment",
            date: Date.new(2017, 1, 3),
            entries: [entry_salary, entry_deposit],
            memo: "paycheck 1")
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
end
