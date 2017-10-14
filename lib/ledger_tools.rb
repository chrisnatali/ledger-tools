require 'money'
Money.use_i18n = false
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
            val.class == String ? /#{val}/ : val
          end
        elsif val.class == Hash
          convert_mapping!(val)
        end
      end
    end
  end
end

