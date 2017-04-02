require 'money'
require 'model'

module LedgerTools

  include Model

  # static class for QIF to Ledger translation and output
  class QIF2Ledger

    # converts the QIF::MoneyQIF parse tree into 
    # an enumerable of LedgerTools::Transaction
    def self.qif_to_transactions(money_qif, asset_account:)
      money_qif.items.map do |item| 
        self.item_to_transaction(item, asset_account: asset_account)
      end
    end

    # writes enumerable of transactions to stream
    def self.write_transactions(io: nil)

    end

    private

    def self.item_to_transaction(item, asset_account:)
      transaction = Transaction.new(name: item.payee, date: item.date)
      entries = []
      # take item or split category as the account for each entry
      #
      # amounts from QIF are positive, but are actually expenses so
      # recorded in ledger as negatives and then balanced by an
      # asset account
      #
      # Money amounts are initialized in cents for USD (hence * 100)
      total = 0
      unless item.splits
        total += item.amount
        entries << Entry.new(
          account: item.category,
          amount: Money.new(-(item.amount) * 100, "USD"), # QIF amounts in dollars
          memo: item.memo)
      else
        item.splits.each do |split|
          total += split.amount
          entries << Entry.new(
            account: split.category,
            amount: Money.new(-(split.amount) * 100, "USD"), # QIF amounts in dollars
            memo: split.memo)
        end
      end
      # add the balancing entry
      entries << Entry.new(
        account: asset_account,
        amount: Money.new(total * 100, "USD"))
      transaction.entries = entries
      transaction
    end

  end
end
