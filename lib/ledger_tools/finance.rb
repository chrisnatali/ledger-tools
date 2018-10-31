module Finance

  MIN_ACCURACY = 1e-12

  class StandardAnnuity
    # Create a new StandardAnnuity with `num_periods` and 2 of the 3 of:
    # `principal`, `periodic_interest`, `payment`
    #
    # Alt signature: 
    # initialize(
    #   num_periods:,
    #   principal: nil,
    #   periodic_interest: nil,
    #   payment: nil
    # )
    def initialize(**kwargs)
      # required params:  this will raise argument error
      required_params = { num_periods: Integer(kwargs[:num_periods]) }

      # 2 of 3 in the optional param_set are required and
      # the lambda is the converter/validator in case the value is specified
      # or not nil
      optional_param_validators = {
        principal: -> val { Integer(val) },
        periodic_interest: lambda do |val|
          i = Float(val)
          if !(0..1).include?(i)
            raise "periodic_interest must be in range (0..1), i: #{i}"
          end
        end,
        payment: -> val { Integer(val) },
      }
          
      optional_params = kwargs.select do |k, v| 
        v != nil && optional_param_validators.keys.include?(k)
      end

      if optional_params.size < 2
        raise ArgumentError("Must have 2 of 3 parameters "\
                            "(#{optional_param_validators.keys}) "\
                            "only got (#{optional_params.keys})")
      end

      # translate optional params and merge with required into @params
      @params = optional_params.map do |k, v| 
        [k, optional_param_validators[k].call(v)]
      end.to_h.merge(required_params)
    end
    
    def num_periods
      @params[:num_periods]
    end

    def principal
      @params[:principal] ||= Finance.annuity_principal(payment, periodic_interest, num_periods)
    end

    def payment
      @params[:payment] ||= Finance.annuity_payment(principal, periodic_interest, num_periods)
    end

    def periodic_interest
      @params[:periodic_interest] ||= Finance.annuity_periodic_interest(principal, payment, num_periods) do |p, i, n|
        Finance.annuity_payment(p, i, n)
      end
    end
  end

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
  def self.annuity_payment(principal, periodic_interest, num_periods)
    # num_periods is 0 means that we pay all principal back immediately
    # so there's no interest accrued and the payment is the principal
    if num_periods == 0
      return principal
    end

    payment = principal / self.annuity_pv_factor(periodic_interest, num_periods)
    payment.round(half: :even)
  end

  def self.annuity_principal(payment, periodic_interest, num_periods)
    # num_periods is 0 here means that the payment is the principal
    if num_periods == 0
      return payment
    end

    payment * self.annuity_pv_factor(periodic_interest, num_periods)
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
  # FV Principal   FV of series of payments
  #  __________    ____________________________________________
  # |          |  |                                            | 
  # p*(1 + i)^n - a*((1 + i)^0 + (1 + i)^1 + ... + (1 + i)^(n-1))
  #                  |______________________________________|
  #                0 based Geom series where common factor is (1 + i)
  #
  # Solving geom series
  # s_0 = (1 + (1 + i) + (1 + i)^2 + ... + (1 + i)^(n - 1)
  # s_0 = ((1 + i)^n - 1)/i
  #
  # Therefore the balance becomes
  #
  # p*(1 + i)^n - a*s_0
  #
  # Good explanation [here](https://money.stackexchange.com/a/61819)
  def self.annuity_balance(principal, periodic_interest, payment, num_periods)
    raise "balance can only be computed for num_periods >= 0" unless num_periods >= 0
    # principal has accrued interest over num_periods (it's future value)
    fv_principal = principal * (1 + periodic_interest)**num_periods
    # payments have been made since 1st period and accrued interest geometrically
    fv_payments = payment * self.annuity_fv_factor(periodic_interest, num_periods)
    
    fv_principal - fv_payments
  end

  def self.annuity_period_interest_amount(annuity_balance, periodic_interest)
    # bankers rounding to minimize error (see https://en.wikipedia.org/wiki/Rounding)
    (annuity_balance * periodic_interest).round(half: :even)
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
  def self.annuity_pv_factor(periodic_interest, num_periods)
    # if interest is 0, the pv is just the amount * num_periods
    if periodic_interest == 0
      return num_periods
    end

    # closed form for the geometric series
    (1 - (1 + periodic_interest)**(-num_periods)) / periodic_interest
  end


  # The FV for annuity with constant payment amount a is 
  # given by:
  #
  # fv = a*((1 + i)^0 + (1 + i)^1 + ... + (1 + i)^(n - 1))
  #        |_______________________________________|
  #       0-based geom. series where common factor is (1 + i)
  #
  # This method returns the factor to be multiplied by
  # the payment amount a in order to get the fv of an
  # annuity after n periods
  #
  def self.annuity_fv_factor(periodic_interest, num_periods)
    # if interest is 0, the pv is just the amount * num_periods
    if periodic_interest == 0
      return num_periods
    end

    # closed form for the geometric series
    ((1 + periodic_interest)**(num_periods) - 1) / periodic_interest
  end

  # Solve for the periodic interest of a given annuity
  # given:  principal, payment and number of periods
  def self.annuity_periodic_interest(
    principal,
    payment,
    num_periods,
    &annuity_payment_method)
    if payment >= principal ||
       num_periods < 0 ||
       payment <= 0 ||
       principal <= 0
      raise StandardError("Invalid parameters: principal #{principal}, "\
                          "payment #{payment}, "\
                          "num_periods #{num_periods}") 
    end
    # Interest range must be from 0 (no interest) to < 1.0
    # (each payment would equal the principal)
    # One millionth accuracy
    # Since the annuity_payment function is monotonic in interest, we can
    # solve for the interest by binary search until we get an annuity_payment
    # that's close enough to what we're looking for
    min_interest = 0
    max_interest = 1.0
    current_interest = (min_interest + max_interest) / 2.0
    current_payment = annuity_payment_method.call(
      principal,
      current_interest,
      num_periods)
    while ((payment - current_payment).abs > MIN_ACCURACY) 
      if current_payment > payment
        max_interest = current_interest
      else
        min_interest = current_interest
      end
      current_interest = (min_interest + max_interest) / 2.0
      current_payment = annuity_payment_method.call(
        principal,
        current_interest,
        num_periods)
    end
    current_interest
  end
end

if $0 == __FILE__

  require 'optparse'
  require 'csv'
  require 'json'

  options = {}

  OptionParser.new do |parser|
    parser.banner = "Usage:  finance.rb [parameters (at least 3)]"
    parser.on('-pPRINCIPAL', '--principal=PRINCIPAL', Integer, 'The Principal amount of the annuity') do |v|
      options[:principal] = v
    end
    parser.on('-aPAYMENT', '--payment=PAYMENT', Integer, 'The periodic payment of the annuity') do |v|
      options[:payment] = v
    end
    parser.on('-nNUM_PERIODS', '--num_periods=NUM_PERIODS', Integer, 'The number of payment periods') do |v|
      options[:num_periods] = v
    end
    parser.on('-iPERIODIC_INTEREST', '--periodic_interest=PERIODIC_INTEREST', Float, 'The periodic interest of the annuity') do |v|
      options[:periodic_interest] = v
    end
    prepayments_help = <<~EOF
    Path to a json file with an array of hashes with :period, :payment keys

    Example prepayments file contents (2 prepayments at period 22 and 30):
    [
      {period: 22, payment: 3000},
      {period: 30, payment: 2000}
    ]
    EOF

    parser.on('-cPREPAYMENTS', '--prepayments=PREPAYMENTS', String, prepayments_help) do |v|
      options[:prepayments] = JSON.parse(File.read(v))
    end
  end.parse!

  # principal = 800_000
  # payment = 4000
  # num_periods = 360
  sa = Finance::StandardAnnuity.new(options.slice(:principal, :payment, :num_periods, :periodic_interest))

  # periodic_interest = Finance.annuity_periodic_interest(
  #   sa.principal,
  #   sa.payment,
  #   sa.num_periods) { |p, i, n| Finance.annuity_payment(p, i, n) }

  # p "principal: #{sa.principal} payment: #{sa.payment} "\
  #   "num_periods: #{sa.num_periods} periodic_interest: #{sa.periodic_interest} "

  # recalculated_payment = Finance.annuity_payment(
  #   sa.principal,
  #   sa.periodic_interest,
  #   sa.num_periods)
  prepayments = options[:prepayments] || []

  schedule = (1..sa.num_periods).map do |period|
    total_prepayments = prepayments.select { |pmt| period > pmt['period'] }.sum { |pmt| pmt['payment'] }

    balance_without_prepay = Finance.annuity_balance(sa.principal, sa.periodic_interest, sa.payment, period - 1)
    annuity_balance = balance_without_prepay - total_prepayments
    period_interest = Finance.annuity_period_interest_amount(annuity_balance, sa.periodic_interest)
    # remainder is the principal
    period_principal = sa.payment - period_interest
    
    {
      period: period,
      period_interest: period_interest,
      period_principal: period_principal
    }
  end

  CSV do |csv_stdout|
    field_names = schedule.map { |record| record.keys }.flatten.uniq
    csv_stdout << field_names
    schedule.each do |record|
      csv_stdout << record.values_at(*field_names)
    end
  end
end
