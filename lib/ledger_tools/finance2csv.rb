require 'ledger_tools'
require 'finance'
require 'csv'

module LedgerTools

  class Finance2CSV

    DEFAULT_COMMODITY = "USD"

    def initialize(options)
      @annuity = Finance::StandardAnnuity.new(options.slice(:principal, :payment, :num_periods, :periodic_interest))
      @prepayments = Finance2CSV.prepayments_for_periods(options[:prepayments] || [], @annuity.num_periods)
      @format_as_ledger_csv = options[:format_as_ledger_csv]
    end

    def self.prepayments_for_periods(prepayments, num_periods)
      prepayments_for_periods = [0] * num_periods
      prepayments.each do |prepayment| 
        period_index = prepayment['period'] - 1
        prepayments_for_periods[period_index] = prepayment['payment']
      end
      prepayments_for_periods
    end

    def schedule
      (1..@annuity.num_periods).map do |period|
        annuity_balance = Finance.annuity_balance(@annuity.principal, @annuity.periodic_interest, @annuity.payment, period - 1, @prepayments)
        period_interest = Finance.annuity_period_interest_amount(annuity_balance, @annuity.periodic_interest)
        # remainder is the principal
        period_principal = @annuity.payment - period_interest

        {
          period: period,
          interest: period_interest,
          principal: period_principal,
          balance: annuity_balance,
        }
      end
    end

    def schedule_as_ledger_records
      schedule.map do |record|
        ledger_record = record.slice(:period)
        [:interest, :principal].map do |amount_field|
          amount_str = Money.new(record[amount_field], DEFAULT_COMMODITY).format(thousands_separator: '', symbol: false)
          ledger_record.merge({account: amount_field, amount: amount_str})
        end
      end.flatten
    end

    def write_csv(output)
      csv = CSV.new(output)
      schedule_records = (@format_as_ledger_csv ? schedule_as_ledger_records : schedule)
      field_names = schedule_records.map { |record| record.keys }.flatten.uniq
      csv << field_names
      schedule_records.each do |record|
        csv << record.values_at(*field_names)
      end
    end
  end
end
