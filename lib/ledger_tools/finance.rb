module LedgerTools::Finance
  # Solves geometric series for the periodic payment for a mortgage
  #
  # A mortgage is like an annuity for the bank where they advance a loan
  # of amount p to a borrower and expect periodic payments back over
  # some time period.  These periodic payments include both the principal
  # of the loan AND the interest that accrues over each period on the
  # remaining principal.
  #
  # Given
  # n:  number of periods
  # i:  periodic interest rate
  # p:  principal of loan (initial amount loaned)
  # 
  # Derive
  # a:  periodic payment amount (a constant amount)
  #
  # The loan repayment formula looks like
  #
  #        principal &
  #        interest
  #        accrued     reduced by
  #        over        period payment
  #        1st            /
  #        period        /             Loan is paid off
  #        __|_____  ___/              by the last payment
  #       |        ||   |                               \
  #  ((...(p*(1 + i) - a)*(1 + i) - a)...)*(1 + i) - a = 0
  #       |__________________________|
  #                   |
  #         remaining principal from
  #         prior period accrues interest
  #         and is reduced by period payment
  #         for n periods
  #  
  # To solve the above equation for p, repeatedly add a then divide by 
  # (1 + i) for each period
  #
  #                                         period n
  #                                         ___|_____
  #                                        |         |
  #  ((...(p*(1 + i) - a)*(1 + i) - a)...)*(1 + i) - a = 0
  #                                      ) = a*(1 + i)^-1
  #                                  ) = a*(1 + i)^-1 +  a*(1 + i)^-2
  #  ...
  #  p = a*(1 + i)^-1 +  a*(1 + i)^-2 + ... + a*(1 + i)^-n
  #  p = a*((1 + i)^-1 + (1 + i)^-2 + ... + (1 + i)^-n)
  #        |__________________________________________|
  #       Geom. series where common factor is (1 + i)^-1
  # 
  #  Solving the geom. series
  #  s = ((1 + i)^-1 + (1 + i)^-2 + ... + (1 + i)^-n)
  #  s = (1 - (1 + i)^-n) / i
  #
  #  plugging back in
  #  
  #  p = a*s <=> a = p / s
  # 
  def self.annuity_payment(principal, interest, num_periods)
    # num_periods is 0 means that we pay all principal back with no interest
    # over 1 period
    if num_periods == 0
      return principal

    principal / self.annuity_pv_factor(interest, num_periods)
  end

  # Compute the principal balance for a period for which the interest
  # is to be computed.  This is the amount of principal remaining
  # AFTER the num_periods specified have passed.
  #
  # p:  principal
  # i:  periodic interest
  # a:  The payment amount per period
  # n:  The number of periods that have accrued
  #
  # We're interested in the balance after only n periods:
  #
  #  ((...(p*(1 + i) - a)*(1 + i) - a)...)*(1 + i) - a = balance
  #
  # This can be converted into:
  #
  # p*(1 + i)^n - a*((1 + i)^0 + (1 + i)^1 + ... + (1 + i)^n)
  #                  |______________________________________|
  #                  0 based Geom series where common factor is (1 + i)
  #
  # Solving geom series
  # s_0 = (1 + (1 + i) + (1 + i)^2 + ... + (1 + i)^n)
  # s_0 = (1 - (1 + i)^(n + 1))/(-i)
  #
  # Therefore the balance becomes
  #
  # p*(1 + i)^n - a*s_0
  def self.annuity_principal_balance(principal, interest, payment, num_periods)
    (p * (1 + interest)**num_periods) - payment * self.annuity_fv_factor(interest, num_periods)
  end

 
  # The PV for annuity with constant payment amount a is 
  # given by:
  #
  # pv = a*((1 + i)^-1 + (1 + i)^-2 + ... + (1 + i)^-n)
  #        |__________________________________________|
  #       Geom. series where common factor is (1 + i)^-1
  #
  # This method returns the factor to be multiplied by
  # the payment amount a in order to get the pv of an
  # annuity with n periods
  #
  def self.annuity_pv_factor(interest, num_periods)
    # if interest is 0, the pv is just the amount * num_periods
    if interest == 0
      return num_periods

    # closed form for the geometric series
    (1 - (1 + interest)**(-num_periods)) / interest
  end


  # The FV for annuity with constant payment amount a is 
  # given by:
  #
  # fv = a*((1 + i)^1 + (1 + i)^2 + ... + (1 + i)^n)
  #        |_______________________________________|
  #       Geom. series where common factor is (1 + i)
  #
  # This method returns the factor to be multiplied by
  # the payment amount a in order to get the fv of an
  # annuity after n periods
  #
  def self.annuity_fv_factor(interest, num_periods)
    # if interest is 0, the pv is just the amount * num_periods
    if interest == 0
      return num_periods

    # closed form for the geometric series
    ((1 + interest)**(num_periods) - 1) / interest
  end
end
