#!/usr/bin/env python3

import argparse
import csv
import re
import periodictable


def build_atom_pattern() -> re.Pattern:
    """Build regex pattern for atom matching"""
    # List of common atoms and their symbols
    atom_symbols = sorted(
        [
            el.symbol
            for el in periodictable.elements
            if el.symbol != "n" and el is not None and el.symbol != "H"
        ],
        reverse=True,
    ) + [  # Aromatic
        "c",
        "n",
        "o",
        "s",
    ]
    # isotope, ion, charged and other in square bracket count as one atom
    atom_pattern = r"\[.*?\]|" + "|".join(atom_symbols)
    return re.compile(atom_pattern)


atom_pattern = build_atom_pattern()


def count_mol_size(smiles: str) -> int:
    """Count molecule size based on number of atoms in SMILES string"""
    mol_size = len(atom_pattern.findall(smiles))
    return mol_size


def filter_molecules_by_size(input_fn, output_fn, smiles_col, size_limit):
    """Filter CSV file based on molecule size"""
    with open(input_fn, "r") as infile, open(output_fn, "w", newline="") as outfile:
        reader = csv.DictReader(infile)
        if reader.fieldnames is None:
            raise ValueError("Input has no header")

        if smiles_col not in reader.fieldnames:
            raise ValueError(f"Column '{smiles_col}' not found")

        writer = csv.DictWriter(outfile, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            smiles = row[smiles_col]
            mol_size = count_mol_size(smiles)

            if mol_size <= size_limit:
                writer.writerow(row)


def main(opts):

    try:
        filter_molecules_by_size(
            opts.input, opts.output, opts.input_smiles_col, opts.limit
        )
        print(f"Filtered molecules saved to {opts.output}")
    except Exception as e:
        print(f"Error: {e}")
        return 1

    return 0


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Filter molecules by size from CSV file"
    )
    parser.add_argument("--input", required=True, help="Input CSV file")
    parser.add_argument(
        "--input-smiles-col",
        type=str,
        default="SMILES",
        help="Name of the column with SMILES data",
    )
    parser.add_argument(
        "--limit", required=True, type=int, help="Maximum molecule size"
    )
    parser.add_argument("--output", required=True, help="Output CSV file")

    return parser.parse_args()


if __name__ == "__main__":
    opts = parse_arguments()
    exit(main(opts))
