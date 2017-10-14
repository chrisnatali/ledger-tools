require 'ledger_tools/qif/qif_parser'

module LedgerTools

  # static class for QIF to Ledger translation and output
  class QIF2Ledger

    include Model
    # converts the QIF::MoneyQIF parse tree into 
    # an enumerable of LedgerTools::Transaction
    def self.qif_to_transactions(money_qif, asset_account:)
      money_qif.items.map do |item| 
        self.item_to_transaction(item, asset_account: asset_account)
      end
    end

    # takes in a QIF and outputs Ledger format
    # TODO:  write tests and handle special cases
    def self.write_qif_as_ledger(input:, output:, asset_account:)
      parser = QIF::Parser.new(input.read)
      qif = parser.parse.qif
      unless qif || qif.is_a?(QIF::MoneyQIF)
        raise LedgerToolsError, "This QIF Format not supported"
      end
      transactions = self.qif_to_transactions(qif, asset_account: asset_account)
      transactions.each do |transaction|
        transaction.to_ledger(io: output)
        output.puts # blank line
      end
    end

    private

    def self.item_to_transaction(item, asset_account:)
      transaction = Transaction.new(name: item.payee, date: item.date)
      entries = []
      # take item or split category as the account for each entry
      #
      # expense amounts from QIF are negative, so we need to negate
      # to "add" to the expense account
      #
      # Money amounts are initialized in cents for USD (hence * 100)
      total = 0
      unless item.splits
        total += item.amount
        entries << Entry.new(
          account: gsub_account_name(item.category),
          amount: Money.new(-(item.amount) * 100, "USD"), # QIF amounts in dollars
          memo: item.memo)
      else
        item.splits.each do |split|
          total += split.amount
          entries << Entry.new(
            account: gsub_account_name(split.category),
            amount: Money.new(-(split.amount) * 100, "USD"), # QIF amounts in dollars
            memo: split.memo)
        end
      end
      # add the balancing entry
      entries << Entry.new(
        account: gsub_account_name(asset_account),
        amount: Money.new(total * 100, "USD"))
      transaction.entries = entries
      transaction
    end

    def self.gsub_account_name(account_name)
      #TODO:  raise if account name missing in parser
      account_name.gsub(/\s{2,}/, " ") if account_name
    end
  end
end
