import os
import random
from typing import cast, List, Tuple

import pandas as pd
import numpy as np
import torch
from torch import Tensor
import dgl
from dgl.data.utils import load_graphs
from dgl.heterograph import DGLHeteroGraph

from rdkit import Chem

ATOM_VOCAB = [
    "C",
    "N",
    "O",
    "S",
    "F",
    "H",
    "Si",
    "P",
    "Cl",
    "Br",
    "Li",
    "Na",
    "K",
    "Mg",
    "Ca",
    "Fe",
    "As",
    "Al",
    "I",
    "B",
    "V",
    "Tl",
    "Sb",
    "Sn",
    "Ag",
    "Pd",
    "Co",
    "Se",
    "Ti",
    "Zn",
    "Ge",
    "Cu",
    "Au",
    "Ni",
    "Cd",
    "Mn",
    "Cr",
    "Pt",
    "Hg",
    "Pb",
]


def one_of_k_encoding(x, vocab):
    if x not in vocab:
        x = vocab[-1]
    return list(map(lambda s: float(x == s), vocab))


def get_atom_feature(atom):  # making one hot encoding about the data
    atom_feature = one_of_k_encoding(atom.GetSymbol(), ATOM_VOCAB)
    atom_feature += one_of_k_encoding(
        atom.GetDegree(), [0, 1, 2, 3, 4, 5]
    )  # number of directly-bonded neighbor
    atom_feature += one_of_k_encoding(
        atom.GetTotalNumHs(), [0, 1, 2, 3, 4]
    )  # number of hydrogen
    atom_feature += one_of_k_encoding(
        atom.GetValence(Chem.IMPLICIT), [0, 1, 2, 3, 4, 5]
    )  # number of implicit Hs on the atom
    atom_feature += [atom.GetIsAromatic()]
    return atom_feature


def get_bond_feature(bond):
    bt = bond.GetBondType()
    bond_feature = [
        bt == Chem.rdchem.BondType.SINGLE,
        bt == Chem.rdchem.BondType.DOUBLE,
        bt == Chem.rdchem.BondType.TRIPLE,
        bt == Chem.rdchem.BondType.AROMATIC,
        bond.GetIsConjugated(),
        bond.IsInRing(),
    ]
    return bond_feature


def get_molecular_graph(smi: str) -> DGLHeteroGraph:
    mol = Chem.MolFromSmiles(smi)
    graph = dgl.graph(([], []))  # just a class, it is constructor

    atom_list = mol.GetAtoms()
    num_atoms = len(atom_list)
    graph.add_nodes(num_atoms)

    atom_feature_list = [get_atom_feature(atom) for atom in atom_list]
    atom_feature_list = torch.tensor(atom_feature_list, dtype=torch.float64)
    graph.ndata["h"] = atom_feature_list

    bond_list = mol.GetBonds()
    bond_feature_list = []
    for bond in bond_list:
        bond_feature = get_bond_feature(bond)

        src = bond.GetBeginAtom().GetIdx()
        dst = bond.GetEndAtom().GetIdx()

        # DGL graph is undirectional
        # Thus, we have to add edge pair of both (i,j) and (j, i)
        # i --> j
        graph.add_edges(src, dst)
        bond_feature_list.append(bond_feature)

        # j --> i
        graph.add_edges(dst, src)
        bond_feature_list.append(bond_feature)

    bond_feature_list = torch.tensor(bond_feature_list, dtype=torch.float64)
    graph.edata["e_ij"] = bond_feature_list
    return graph


def smi_collate_fn(batch: List[Tuple[str, float]]) -> Tuple[DGLHeteroGraph, Tensor]:
    graph_list: List[DGLHeteroGraph] = []
    label_list: List[float] = []
    for item in batch:
        smi_: str = item[0]
        label: float = item[1]

        graph = get_molecular_graph(smi_)
        graph_list.append(graph)
        label_list.append(label)
    graph_res: DGLHeteroGraph = dgl.batch(graph_list)
    label_res: Tensor = torch.tensor(label_list, dtype=torch.float64)
    return graph_res, label_res


def load_collate_fn(batch):
    graph_list = []
    label_list = []
    for item in batch:
        id_ = item[0]
        label = item[1]

        idx = int(id_.split("_")[1])
        conformer_idx = idx // 10000
        graph_path = os.path.join(
            "data/Enamine_HTS/", "dgl_graph", str(conformer_idx), id_ + ".bin"
        )
        graph = load_graphs(graph_path)
        graph_list.append(graph[0][0])
        label_list.append(label)
    graph_list = dgl.batch(graph_list)
    label_list = torch.tensor(label_list, dtype=torch.float64)
    return graph_list, label_list


def get_dataset(
    title,
    seed,
    step,
    method,
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    data_dir = os.path.join(
        "data",
    )
    if step == 0:
        train_path = os.path.join(
            data_dir, title + "_seed" + str(seed) + "_step" + str(step) + "_train.csv"
        )
    else:
        train_path = os.path.join(
            data_dir,
            title
            + "_seed"
            + str(seed)
            + "_step"
            + str(step)
            + "_"
            + method
            + "_train.csv",
        )
    valid_path = os.path.join(
        data_dir, title + "_seed" + str(seed) + "_step0" + "_valid.csv"
    )
    test_path = os.path.join(
        data_dir, title + "_seed" + str(seed) + "_step0" + "_test.csv"
    )
    train_set = pd.read_csv(train_path)
    valid_set = pd.read_csv(valid_path)
    test_set = pd.read_csv(test_path)
    return train_set, valid_set, test_set


class MyDataset(torch.utils.data.Dataset):
    def __init__(
        self,
        splitted_set: pd.DataFrame,
        smiles_col: str,
        target_col: str,
    ):
        self.smiles_col = smiles_col
        self.target_col = target_col
        self.smiles_list = list(splitted_set[self.smiles_col])
        # self.id_list = list(splitted_set['ID'])
        self.target_list = list(splitted_set[self.target_col])

    def __len__(self):
        return len(self.smiles_list)

    def __getitem__(self, idx):
        return self.smiles_list[idx], self.target_list[idx]


def debugging():
    print("Hello!")


if __name__ == "__main__":
    debugging()
