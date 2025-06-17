import pytest

from bin.obabel_batch import process_molecules


def test_obabel_batch():
    csv = """\
ID,SMILES
CHEMBL153534,Cc1cc(-c2csc(N=C(N)N)n2)cn1C,
CHEMBL503643,CCOC(=O)c1cc2cc(C(=O)O)ccc2[nH]1
"""
    assert reverse_complement("NNNN") == "NNNN"
