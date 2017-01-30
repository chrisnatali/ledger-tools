require "qif_parser"

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

describe QIF::Parser do
	describe "#parse" do
		context "given a valid string" do
			it "returns transactions and records" do
				parser = QIF::Parser.new
				txns = parser.parse(GOOD_QIF)
				expect(txns.length).to be > 0
				txns.each do |t|	
					expect(t).to be_a QIF::Transaction	
					expect(t.records.length).to be > 0
						t.records.each do |r|
							expect(r).to be_a QIF::Record
						end
				end
			end
		end
	end
end
