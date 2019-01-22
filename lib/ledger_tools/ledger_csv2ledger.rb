require 'ledger_tools'
require 'csv'

module LedgerTools

  include Model
  # class for Ledger CSV to Ledger format
  # Assumes each CSV row corresponds to a single ledger entry/posting
  # with the following fields:
  #
  #    Transaction fields                      Entry fields
  #  ________|_________________________   __________|___________________________
  # |                                  | |                                      |
  # txnidx,date,code,description,comment,account,commodity,amount,posting-comment
  # 
  # with entries being associated with their transaction via
  # the unique values in the transaction fields
  class LedgerCSV2Ledger

    DEFAULT_AMOUNT_FACTOR = 100
    DEFAULT_COMMODITY = "USD"
    TRANSACTION_FIELDS = ['txnidx', 'date', 'code', 'description', 'status', 'comment'].freeze
    ENTRY_FIELDS = ['account', 'commodity', 'amount', 'posting-comment'].freeze

    # converts the CSV into an Array of LedgerTools::Transaction
    # Note:  Needs to process all records before returning since
    # we don't assume a transactions entries are contiguous in the csv
    def csv_to_transactions(csv)
      transactions = {}
      csv.each do |record| 
        begin 
          transaction_values = record.to_h.values_at(*TRANSACTION_FIELDS)
          txn_idx, date, code, description, status, comment = transaction_values
          # remove any newline/indentation/; chars from comment field
          comment = comment.sub(/\s*[;]?/, "")
          date = Date.strptime(date, "%Y/%m/%d")
          transaction = (transactions[transaction_values] ||=
                         Model::Transaction.new(name: description, date: date, code: code, entries: [], status: status, memo: comment))
          entry = record_to_entry(record)
          transaction.entries << entry
        rescue CSV::MalformedCSVError => e
          p record
          raise e
        end
      end
      transactions.values
    end

    def record_to_entry(record)
      # Ignore commodity field for now
      account, commodity, amount, comment = record.to_h.values_at(*ENTRY_FIELDS)
      # remove any newline/indentation/; chars from comment field
      comment = comment.sub(/\s*[;]?/, "")
      amount = amount.gsub(/[^\d^\.^-]/, '') if amount.is_a?(String)
      total = amount.to_f * DEFAULT_AMOUNT_FACTOR
      Model::Entry.new(
        account: account,
        amount: Money.new(total, DEFAULT_COMMODITY),
        memo: comment
      )
    end

    # takes in a CSV and outputs Ledger format
    # TODO:  handle exceptions and write tests
    def write_csv_as_ledger(input, output)
      csv = CSV.new(input, headers: true)
      transactions = csv_to_transactions(csv)
      transactions.each_with_index do |transaction, index|
        transaction.to_ledger(io: output)
        # separate with blank line if not the last
        if index < (transactions.size - 1)
          output.puts
        end
      end
    end
  end
end
