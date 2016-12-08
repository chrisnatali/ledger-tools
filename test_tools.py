from qif_parser import QIFParser

def test_qif_parser():
    # TODO:  Move to tests
    good_qif = "D11/ 8'16\r\nU-107.88\nT-107.88\nPVERIZON\nLUtilities\n^\nD11/ 9'16\nU-1,570.73\nPChecking\nLVisa\n^" # noqa
    qif_parser = QIFParser()
    for t in qif_parser.parse(good_qif):
        assert(len(t.records) > 1)    

    bad_qif = "D11/ 8'16\nU-107.88\nT-107.88\nPVERIZON\nQ^\nZ^" # no_qa

    try:
        for t in qif_parser.parse(bad_qif):
            assert(False)
    except SyntaxError as e:
        assert("{}".format(e).find("Q^") != -1)
