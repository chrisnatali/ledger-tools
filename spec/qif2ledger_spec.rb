require 'qif2ledger'
require 'qif_parser'

include LedgerTools 

describe QIF2Ledger do
  let(:item_utility) do
    item = QIF::Item.new(Date.new(2016, 11, 8), -107.88)
    item.payee = "VERIZON"
    item.category = "Expenses:Utilities"
    item
  end
  let(:splits_salary) do
    split_salary = QIF::Split.new("Income:Salary")
    split_salary.amount = 1000.00
    split_tax = QIF::Split.new("Expenses:Tax")
    split_tax.amount = -200.00
    [split_salary, split_tax]
  end
  let(:item_splits) do
    item = QIF::Item.new(Date.new(2017, 1, 3))
    item.payee = "Employer"
    item.splits = splits_salary
    item
  end
  let(:money_qif) do 
    asset_account = QIF::Account.new("Assets:Checking")
    QIF::MoneyQIF.new(asset_account, [item_utility, item_splits])
  end
  let(:transaction_utility) do
    transaction = Model::Transaction.new(
      name: "VERIZON",
      date: Date.new(2016, 11, 8))
    entries = []
    entries << Entry.new(
      account: "Expenses:Utilities", 
      amount: Money.new(107_88, "USD"))
    entries << Entry.new(
      account: "Assets:Checking",
      amount: Money.new(-107_88, "USD"))
    transaction.entries = entries
    transaction
  end
  let(:transaction_splits) do
    transaction = Model::Transaction.new(
      name: "Employer",
      date: Date.new(2017, 1, 3))
    entries = []
    entries << Entry.new(
      account: "Income:Salary", 
      amount: Money.new(-1000_00, "USD"))
    entries << Entry.new(
      account: "Expenses:Tax", 
      amount: Money.new(200_00, "USD"))
    entries << Entry.new(
      account: "Assets:Checking",
      amount: Money.new(800_00, "USD"))
    transaction.entries = entries
    transaction
  end

  describe "#qif_to_transactions" do
    let(:transactions) { QIF2Ledger.qif_to_transactions(money_qif, asset_account: "Assets:Checking") }
    context "simple transaction" do
      let(:transaction) { transactions[0] }
      it "matches expected transaction" do
        expect(transaction).to eq(transaction_utility)
      end
    end
    context "split transaction" do
      let(:transaction) { transactions[1] }
      it "matches expected transaction" do
        expect(transaction).to eq(transaction_splits)
      end
    end
  end
end
