# Module and Class to parse a QIF file into Transactions composed of Records

module QIF
	Transaction = Struct.new(:type, :records)
	Record = Struct.new(:type, :value_hash)
	class Parser
		def parse(text)
			[Transaction.new("NORMAL", [Record.new("T_AMOUNT", {"amount": 3.00})])]
		end
	end
end


