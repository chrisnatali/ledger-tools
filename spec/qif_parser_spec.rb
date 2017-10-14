require 'spec_helper'
require 'qif_parser_fixtures'

module LedgerTools::QIF
  describe Parser do
    describe "#parse" do
      context "given a valid string" do
        it "returns a MoneyQIF as root" do
          parser = Parser.new(QIFFixtures::GOOD_QIF)
          root = parser.parse
          expect(root.header.type).to eq("Bank")
          expect(root.qif.class).to eq(MoneyQIF)
        end
      end
    end

    describe "#parse_header" do
      let(:bank_header) { Header.new("Bank") }
      let(:invst_header) { Header.new("Invst") }
      context "given no header" do
        subject { Parser.new("") }
        it "returns Bank header" do
          expect(subject.parse_header).to eq(bank_header)
        end
      end
      context "given good header" do
        subject { Parser.new("!Type:Invst\n") }
        it "returns Invst header" do
          expect(subject.parse_header).to eq(invst_header)
        end
      end
    end

    describe "#parse_account" do
      let(:account) { Account.new("Checking", "Bank", "\"Personal Checking\"") }
      context "given account info" do
        account_text = <<~EOF
        !Account
        NChecking
        TBank
        D"Personal Checking"
        ^
        EOF

        subject { Parser.new(account_text) }
        it "returns account" do
          expect(subject.parse_account).to eq(account)
        end
      end

      context "given bad account info" do
        account_text = <<~EOF
        !Account
        QBad Field
        ^
        EOF

        subject { Parser.new(account_text) }
        it "raises exception" do
          expect { subject.parse_account }.to raise_error(ParseError)
        end
      end
    end

    describe "#parse_item" do
      let(:item_no_split) { 
        Item.new(
          Time.new(2016, 1, 1), 
          100.10, 
          "X",
          "123",
          "Sal",
          "Socks",
          ["123 Van Buren St", "Passaic", "NJ"],
          "Clothing",
          nil
        ) 
      }
      let(:item_split) { 
        Item.new(
          Time.new(2016, 1, 1), 
          100.10, 
          "X",
          nil,
          "Employer",
          "Pay",
          nil,
          nil,
          [Split.new("Income:Salary", nil, 110.10), 
           Split.new("Expenses:Tax", "NY", -10.00)]
        ) 
      }
      context "given no split item info" do
        item_text = <<~EOF
        D1/1'16
        U100.10
        CX
        N123
        PSal
        MSocks
        A123 Van Buren St
        APassaic
        ANJ
        LClothing
        ^
        EOF

        subject { Parser.new(item_text) }
        it "returns item without split" do
          expect(subject.parse_item).to eq(item_no_split)
        end
      end

      context "given split item info" do
        item_text = <<~EOF
        D1/1'16
        U100.10
        CX
        PEmployer
        MPay
        SIncome:Salary
        $110.10
        SExpenses:Tax
        ENY
        $-10.00
        ^
        EOF

        subject { Parser.new(item_text) }
        it "returns item with splits" do
          expect(subject.parse_item).to eq(item_split)
        end
      end

   
      context "given bad item info" do
        item_text = <<~EOF
        D6/19' 5
        QBad Field
        ^
        EOF

        subject { Parser.new(item_text) }
        it "raises exception" do
          expect { subject.parse_item }.to raise_error(ParseError)
        end
      end
    end
  end
end
