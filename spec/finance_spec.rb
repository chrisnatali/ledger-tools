require 'spec_helper'

# Require finance sub-module here since it's not required in spec_helper
# and is NOT in the LedgerTools namespace (will be moved out eventually)
require 'finance'

# TODO:  Test PV/FV for
# - 0 interest
# - 0 num_periods
# - n num_periods where n matches the num_periods used to determine `annuity_payment`
# - 0 payment amount
# - fv = (1 + i)^n*pv

describe Finance::StandardAnnuity do
end 

describe 'Finance.annuity_balance' do
  let(:principal) { 1000.0 }
  let(:num_periods) { 2 }
  let(:periodic_interest) { 5/100r } # 5 percent as rational
  let(:payment) { Finance.annuity_payment(principal, periodic_interest, num_periods) }
  let(:tolerance) { 1e-8 }

  context 'when all payments equal' do
    let(:payments_for_periods) { [payment] * num_periods }

    it 'matches annuity_balance_custom' do
      (0..num_periods).each do |period| 
        balance = Finance.annuity_balance(principal, periodic_interest, payment, period)
        balance_custom = Finance.annuity_balance_custom(principal, periodic_interest, payments_for_periods, period)
        expect(balance).to be_within(tolerance).of(balance_custom)
      end
    end
  end

  context 'when there are prepayments' do
    let(:prepayments_for_periods) { [100.0, 0.0] }
    let(:payments_for_periods) { prepayments_for_periods.map { |prepayment| prepayment + payment } }

    it 'matches annuity_balance_custom' do
      (0..num_periods).each do |period| 
        balance = Finance.annuity_balance(principal, periodic_interest, payment, period, prepayments_for_periods)
        balance_custom = Finance.annuity_balance_custom(principal, periodic_interest, payments_for_periods, period)
        expect(balance).to be_within(tolerance).of(balance_custom)
      end
    end
  end
end
