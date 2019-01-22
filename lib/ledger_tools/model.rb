require 'money'

module LedgerTools

  module Model

    # Basic accounting model
    #
    # Account --< Entry >-- Transaction
    #
    # An entry refers to an account by it's name for now
    #
    # Follows the plain-text-accounting ledger model

    INDENT_SPACES = "    "
    class Account
      attr_accessor :name
      def initialize(name:)
        @name = name
      end
    end

    class Entry
      # amount should be a Money object
      attr_accessor :account, :amount, :memo
      def initialize(account:, amount:, memo: nil)
        @account = account
        @amount = amount
        @memo = memo
      end

      def to_ledger_string
        entry_str =  "#{INDENT_SPACES}#{@account}  #{@amount.format(thousands_separator: ',')}"
        memo_str = "\n#{INDENT_SPACES};#{@memo}" if !(@memo.nil? || @memo.empty?)
        "#{entry_str}#{memo_str}"
      end
    end

    class Transaction
      attr_accessor :name, :date, :entries, :code, :status, :memo
      def initialize(name:, date:, entries: nil, code: nil, status: nil, memo: nil)
        @name = name
        @date = date
        @entries = entries
        @code = code
        @status = status
        @memo = memo
      end

      def to_ledger(io:)
        date_str = @date.strftime('%Y-%m-%d')
        status_str = "#{@status}" if !(@status.nil? || @status.empty?)
        code_str = "(#{@code})" if !(@code.nil? || @code.empty?)
        memo_str = "\n#{INDENT_SPACES};#{@memo}" if !(@memo.nil? || @memo.empty?)

        io.puts "#{[date_str, status_str, code_str, name].compact.join(" ")}#{memo_str}"
        entries.each { |entry| io.puts entry.to_ledger_string }
      end

      def to_ledger_string
        StringIO.open do |s| 
          to_ledger(io: s)
          s.string
        end
      end

      def ==(other)
        Model::get_object_attributes(self) == Model::get_object_attributes(other)
      end
    end

    def self.get_object_attributes(obj)
      obj.instance_variables.map do |sym|
        val = obj.instance_variable_get(sym)
        if val.is_a? Enumerable
          val.map { |val_obj| self.get_object_attributes(val_obj) }
        elsif [Transaction, Entry, Account, Money].include?(val.class)
          self.get_object_attributes(val)
        elsif val.is_a? String or val.is_a? Numeric or val.is_a? Date
          val
        end
      end
    end
  end
end
