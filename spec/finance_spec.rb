require 'spec_helper'

include LedgerTools::Finance

# TODO:  Test PV/FV for
# - 0 interest
# - 0 num_periods
# - n num_periods where n matches the num_periods used to determine `annuity_payment`
# - 0 payment amount
# - fv = (1 + i)^n*pv

