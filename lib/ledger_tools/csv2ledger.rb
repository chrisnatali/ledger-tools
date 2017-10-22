require 'ledger_tools'
require 'csv'

module LedgerTools

  include Model
  # class for CSV to Ledger translation and output
  # Assumes each CSV row corresponds to a single transaction
  # with 2 entries (from and to)
  # And that the account to balance each transaction with is
  # always the same (i.e. a bank account)
  # TODO:  Add Example
  class CSV2Ledger
    attr_reader :field_mappings, :payee_mappings, :account_mappings

    DEFAULT_AMOUNT_FACTOR = 100
    DEFAULT_COMMODITY = "USD"
    DEFAULT_FIELD_MAPPINGS = {
      'date' => 'date',
      'account' => 'account',
      'payee' => 'payee',
      'amount' => 'amount',
    }
    REQUIRED_FIELDS = %w{date account payee amount}.freeze
    DEFAULT_TRANSACTION_TYPE = 'debit'
    DEFAULT_TRANSACTION_TYPE_FACTOR = 1

    # Construct a new CSV2Ledger instance 
    # 
    # field_mappings:  input transaction_field => csv_field
    #   Must define mapping for:  payee, account, amount, date
    #   If csv_field is of form ':<transaction_field>' then
    #   use the "post-mapping" value of that transaction field
    #   as the input value for the transaction_field
    # payee_mappings:  payee => [payee regex,...]
    #   Map a standard payee to the record via a regex
    # account_mappings:  account => [account regex,...]
    #   Map a standard account to the record via a regex
    # date_format: (see Date#strptime)
    # balance_account:  Account to balance out each transaction with
    # transaction_type_mappings:  value => [transaction_type category regex]
    #   Map a standard transaction_type to the record via a regex
    # transaction_type_factor_mapping:  txn_type => factor
    #   Map a standard transaction_type to a factor to multiply amount by
    def initialize(field_mappings: nil,
                   payee_mappings: nil,
                   account_mappings: nil,
                   date_format: "%Y-%m-%d",
                   balance_account: "Assets:BankAccount",
                   transaction_type_mappings: nil,
                   transaction_type_factor_mapping: nil)

      @field_mappings = field_mappings || DEFAULT_FIELD_MAPPINGS
      @payee_mappings = payee_mappings || {}
      @account_mappings = account_mappings || {}
      @date_format = date_format
      @balance_account = balance_account
      @transaction_type_mappings = transaction_type_mappings || {}
      @transaction_type_factor_mapping = transaction_type_factor_mapping || {}

      # convert match strings to regexes where appropriate
      Util::convert_mapping_match_to_regex!(@payee_mappings)
      Util::convert_mapping_match_to_regex!(@account_mappings)
      Util::convert_mapping_match_to_regex!(@transaction_type_mappings)
      validate
    end

    # converts the CSV into an enumerable of LedgerTools::Transaction
    def csv_to_transactions(csv)
      csv.map do |record| 
        record_to_transaction(record)
      end
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
          output.puts # blank line
        end
      end
    end

    # Replace value with first matching value from 
    # mapping or if no matches, leave it
    def lookup(mapping, value)
      mapping.each do |match_name, regex_list|
        regex_list.each do |regex|
          if value =~ regex
            return match_name 
          end
        end
      end
      value
    end

    def record_to_transaction(record)
      @record = record
      transaction = Model::Transaction.new(name: payee, date: date)
      total = amount * DEFAULT_AMOUNT_FACTOR * transaction_type_factor
      main_entry = Model::Entry.new(
        account: account,
        amount: Money.new(total, DEFAULT_COMMODITY), # assumes amounts in dollars
        memo: "#{@record}".gsub(/\n/, "")) # rm \n added by CSV::Row#to_s
      balance_entry = Model::Entry.new(
        account: @balance_account,
        amount: Money.new(-total, DEFAULT_COMMODITY))
      # Try to always put debit entries first
      entries = if transaction_type == :debit 
        [main_entry, balance_entry]
      else 
        [balance_entry, main_entry] # main entry is credit, balance goes 1st
      end
      transaction.entries = entries
      transaction
    end

    private
    
    def date
      value = @record[@field_mappings['date']]
      Date.strptime(value, @date_format)
    end

    def payee
      value = @record[@field_mappings['payee']]
      lookup(@payee_mappings, value)
    end

    def account 
      field = @field_mappings['account']
      # if the field is a method of this class
      # we use ":method_name" to distinguish
      if field =~ /^:/
        value = self.send(field.sub(/^:/, "").to_sym)
        # TODO: raise check config
      else
        value = @record[field]
      end
      lookup(@account_mappings, value)
    end
    
    def transaction_type
      value = @record[@field_mappings['transaction_type']] 
      value ||= DEFAULT_TRANSACTION_TYPE
      lookup(@transaction_type_mappings, value).to_sym
    end

    def transaction_type_factor
      factor = @transaction_type_factor_mapping[transaction_type.to_s]
      (factor || DEFAULT_TRANSACTION_TYPE_FACTOR).to_f
    end

    def amount
      @record[@field_mappings['amount']].to_f
    end

    def validate
      unless REQUIRED_FIELDS.all? do |field| 
        @field_mappings.keys.include?(field)
      end
        raise ArgumentError.new(
          "field_mapping must include mapping for all in #{REQUIRED_FIELDS}")
      end
    end
  end
end
