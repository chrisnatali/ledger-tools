# Module and Class to parse a QIF file into Transactions composed of Records
require 'strscan'

module QIF

  # Structure of a QIF file is outlined [here](https://en.wikipedia.org/wiki/Quicken_Interchange_Format)
  # and specified in detail [here](https://www.w3.org/2000/10/swap/pim/qif-doc/QIF-doc.htm)
  #
  # Here's a grammar def ($ denotes end of line or end of file)
  #
  # Root := MoneyHeader MoneyQIF | InvestmentHeader InvestmentQIF | CategoryHeader CategoryQIF | ClassHeader ClassQIF 
  # MoneyQIF := AccountForItems? Item*
  # AccountQIF := Account*
  # AccountForItems := AccountHeader Account
  # MoneyHeader := '!Type:' 'Bank' | 'Cash' | 'CCard' | 'Oth A' | 'Oth L' $
  # InvestmentQIF := InvestmentItem*
  # AccountHeader := '!Account' $
  # InvestmentHeader := '!Type:Invst' $
  # CategoryQIF := Category*
  # CategoryHeader := '!Type:Cat' $
  # ClassQIF := Class*
  # ClassHeader := '!Type:Class' $
  # Account := AccountField* '^' $
  # Category := CategoryField* '^' $
  # Class := ClassField* '^' $
  # Item := ItemField* '^' $
  # ItemField := Date | Amount | Cleared | CheckNum | Payee | Memo | Address | Category | SplitCategory | SplitMemo | SplitAmount
  # InvestmentItem := InvestmentItemField* '^' $
  # InvestmentItemField := Date | Action | Security | Price | Quantity | Amount | Cleared | PNote | Memo | Commission | TransferAccount | TransferAmount
  # AccountField := Name | Type | Description | CreditLimit | BalanceDate | BalanceAmount
  # CategoryField := Name | Description | TaxRelated | IncomeCategory | ExpenseCategory | BudgetAmount | TaxSchedule
  # ClassField := Name | Description
  #
  Root = Struct.new(:header, :qif)
  MoneyQIF = Struct.new(:account, :items)
  InvestmentQIF = Struct.new(:investment_items)
  CategoryQIF = Struct.new(:categories)
  ClassQIF = Struct.new(:classes)
  Header = Struct.new(:type)
  Account = Struct.new(:name, :type, :description) # Add these if needed: :credit_limit, :balance_date, :balance_amount)
  Category = Struct.new(:name, :description) # Add if needed: :tax_related, :income_category, :expense_category, :budget_amount, :tax_schedule)
  Class = Struct.new(:name, :description)
  # An item is roughly equivalent to a transaction in other accounting contexts
  Item = Struct.new(:date, :amount, :cleared, :check_num, :payee, :memo, :address, :category, :splits)
  InvestmentItem = Struct.new(:date, :action, :security, :price, :quantity, :amount, :cleared, :pnote, :memo, :commission, :transfer_account, :transfer_amount)
  Field = Struct.new(:type, :value)
  Split = Struct.new(:category, :memo, :amount)
  
  TRANSACTION_HEADER_TYPES = ["Bank", "Cash", "CCard", "Oth A", "Oth L"].freeze
  INVESTMENT_HEADER_TYPES = ["Invst"].freeze
  CATEGORY_HEADER_TYPES = ["Cat"].freeze

  class ParseError < StandardError; end
  class UnsupportedTypeError < ParseError; end

  # Defines a Recursive Descent parser for files conforming to the grammar
  # defined above
  # 
  # Once initialized with the text of the file, the main entry point is
  # the #parse method
  class Parser

    # General token regex's to be plugged in
    EOL = /(?:\n|\r\n)/
    MONTH = /(?<month>[ 01]?[\d])/
    DAY = /(?<day>[ 0123]?[\d])/
    YEAR_SHORT = /(?<year_short>[ ]?\d[\d]?)/
    YEAR_LONG = /(?<year_long>[\d]{4})/
    DATE = /#{MONTH}\/#{DAY}(('#{YEAR_SHORT})|(\/#{YEAR_LONG}))#{EOL}/
    AMOUNT = /(?<amount>-?[\d,]+(\.[\d]+)?)#{EOL}/
    VALUE = /(?<value>.*)#{EOL}/

    def initialize(text)
      @scanner = StringScanner.new(text)
    end

    def parse
      header = parse_header
      qif = nil
      if TRANSACTION_HEADER_TYPES.include?(header.type)
        # A Money QIF, so parse the optional account and items
        account = parse_account
        items = []
        until @scanner.eos?
          items << parse_item
        end
        qif = MoneyQIF.new(account, items)
      else
        raise UnsupportedTypeError, "Header type #{header.type} not supported"
      end
      Root.new(header, qif)
    end

    def parse_header
      if @scanner.scan(/!Type:(?<header_type>\w+)$/) 
        Header.new(@scanner[:header_type])
      else
        # Bank is default file type
        Header.new("Bank")
      end
    end

    def parse_account
      # Want only fields that match 
      #
      # structure of field_match is:
      # {
      #   field_name1: {match: regex_for_match, parse: parse_method },
      #   ..
      # }
      #
      # where parse_method will reference the StringScanner and parse
      # the value(s) specific to that field type
      field_match = {
        name: {match: /N#{VALUE}/, parse: :parse_value},
        type: {match: /T#{VALUE}/, parse: :parse_value},
        description: {match: /D#{VALUE}/, parse: :parse_value}
      }
      if @scanner.scan(/!Account#{EOL}/)
        account = Account.new
        until @scanner.scan(/\^#{EOL}/)
          field_name, match_parse = field_match.find {|field, match| @scanner.scan(match[:match])}
          raise ParseError, "Account parse error" unless field_name
          # we only want 1 of each field, so remove this match from available
          field_match.delete(field_name)
          account.send "#{field_name}=", send(match_parse[:parse])
        end    
        return account
      end
    end
    
    def parse_item
      # Want only fields that match the following
      #TODO:  Some files have both T and U amount fields
      field_match = {
        date: {match: /D#{DATE}/, parse: :parse_date},
        amount: {match: /(?:T|U)#{AMOUNT}/, parse: :parse_amount},
        cleared: {match: /C(?<value>[\*cXR])#{EOL}/, parse: :parse_value},
        check_num: {match: /N#{VALUE}/, parse: :parse_value},
        payee: {match: /P#{VALUE}/, parse: :parse_value},
        memo: {match: /M#{VALUE}/, parse: :parse_value},
        address: {match: /A#{VALUE}/, parse: :parse_value},
        category: {match: /L#{VALUE}/, parse: :parse_value},
        split: {match: /S(?<category>.*)#{EOL}(E(?<memo>.*)#{EOL})?\$#{AMOUNT}/, parse: :parse_split}
      }
      item = Item.new
      splits = []
      until @scanner.scan(/\^#{EOL}/)
        field_name, match_parse = field_match.find {|field, match| @scanner.scan(match[:match])}
        unless field_name
          raise ParseError, "Item parse error"
        end
        # splits and amounts are special cases
        if field_name == :split
          splits << parse_split
        elsif field_name == :amount
          # set the value of the field to the parsed value
          value = send(match_parse[:parse])
 
          if item.amount && (item.amount != value)
            warn "differing amount values are not allowed: using #{item.amount} ignoring #{value}"
          else
            item.amount = value
          end
        else
          # we only want 1 of each non-special field, so remove this match from available
          field_match.delete(field_name)
          # ONLY if field_name matches what item expects
          if item.members.include?(field_name)
            item.send "#{field_name}=", send(match_parse[:parse])
          end
        end    
      end
      if splits.size > 0
        item.splits = splits
      end
      return item
    end

    private

    def parse_date
      # get the :month, :day, :year from @scanner and
      # return Date object
      month = @scanner[:month].to_i
      day = @scanner[:day].to_i
      if @scanner[:year_short]
        year = @scanner[:year_short].to_i
        year += (year > 50 ? 1900 : 2000)
      else
        year = @scanner[:year_long].to_i
      end
      Time.new(year, month, day)
    end

    def parse_amount
      # get the :amount value and return an amount as float
      @scanner[:amount].gsub(',', '').to_f
    end

    def parse_value
      @scanner[:value]
    end

    def parse_split
      category = @scanner[:category]
      memo = @scanner[:memo]
      amount = parse_amount
      Split.new(category, memo, amount)
    end
  end
end
