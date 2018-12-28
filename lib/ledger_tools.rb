require 'money'
Money.locale_backend = nil # :i18n  # use_i18n = false
require 'ledger_tools/model'
require 'ledger_tools/qif2ledger'
require 'ledger_tools/csv2ledger'

module LedgerTools
  class Error < StandardError; end

  module Util
    # Given a hierarchical hash_map of key => sub_key... => array_of_strings
    # convert the array_of_strings to an array_of_regexes
    # Note:  mutates the hash
    def self.convert_mapping_match_to_regex!(hash_map)
      hash_map.each do |key, val|
        if val.class == Array
          hash_map[key] = val.map do |val| 
            # TODO:  if not a string, raise?
            val.class == String ? /#{val}/ : val
          end
        elsif val.class == Hash
          convert_mapping!(val)
        end
      end
    end

    def self.generate_mortgage_schedule(principal, annual_rate, num_years)
      # derived from http://www.konfluence.org/geomser/geomser.html  
      monthly_rate = annual_rate / 12.0
      num_months = num_years * 12
      principal_with_no_payments = principal*((1 + monthly_rate)**(num_months))
      monthly_factor = ((1 + monthly_rate)**(num_months) - 1) / monthly_rate
      monthly_amount = principal_with_no_payments / monthly_factor
      gen = Enumerator.new do |y|
        (1...num_months).each do |month|
          interest_payment = principal * monthly_rate
          principal_payment = monthly_amount - interest_payment
          principal = principal - principal_payment
          y << [month, interest_payment, principal_payment, principal]
        end
      end
    end
  end
end

