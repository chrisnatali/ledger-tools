module QIFFixtures

  GOOD_QIF = <<~EOF
  D11/ 8'16
  U-107.88
  T-107.88
  PVERIZON
  LUtilities
  ^
  D11/ 9'16
  U-1,570.73
  PChecking
  LVisa
  ^
  EOF

  BAD_QIF = <<~EOF
  D11/ 8'16
  U-107.88
  T-107.88
  PVERIZON
  Q^
  Z^
  EOF

end

