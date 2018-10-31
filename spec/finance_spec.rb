require 'spec_helper'

# Require finance sub-module here since it's not required in spec_helper
# and is NOT in the LedgerTools namespace (will be moved out eventually)
require 'ledger_tools/finance'

# TODO:  Test PV/FV for
# - 0 interest
# - 0 num_periods
# - n num_periods where n matches the num_periods used to determine `annuity_payment`
# - 0 payment amount
# - fv = (1 + i)^n*pv

describe Finance::StandardAnnuity do
end 

describe 'Finance.annuity_balance' do
  context 'when num_periods is 0' do
  end

  context 'when the balance is easy to compute' do
  end
end
