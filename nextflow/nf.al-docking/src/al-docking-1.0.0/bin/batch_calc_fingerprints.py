#!/usr/bin/env python3

import argparse
import csv
from dataclasses import dataclass, field
import hashlib
import os
import re
import subprocess
from pathlib import Path
import sys
from typing import Dict, Union

from rdkit import Chem
from rdkit.Chem.rdFingerprintGenerator import GetMorganGenerator, FingerprintGenerator64

add_cols = argparse.Namespace(ecfp="ECFP")


@dataclass(frozen=True)
class Options:
    input: str
    input_id_col: str
    input_smiles_col: str
    ecfp_radius: int
    ecfp_nbits: int
    output: str


def parse_args() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser(description="Batch ECFP calculation script")
    parser.add_argument(
        "--input", type=lambda x: x if os.path.isfile(x) else parser.error(f"File {x} does not exist"), 
        required=True, help="Input CSV file with SMILES (file path)")
    parser.add_argument(
        "--input-id-col", default="ID", 
        help="Input CSV file molecule ID column name (default: ID)")
    parser.add_argument(
        "--input-smiles-col", default="SMILES",
        help="Input CSV file molecule SMILES value column name")
    
    parser.add_argument(
        "--ecfp-radius", type=int, default=2,
        help="ECFP param radius")
    parser.add_argument(
        "--ecfp-nbits", type=int, default=512,
        help="ECFP param bits size")
 
    parser.add_argument(
        "--output", type=str, required=True, 
        help="Output CSV file with ECFP")
    # fmt: on

    return Options(**vars(parser.parse_args()))


@dataclass(frozen=True)
class FingerprintRes:
    ecfp: str


def process_molecule(
    mol_id: str,
    mol_smiles: str,
    morgan_generator: FingerprintGenerator64,
) -> FingerprintRes:
    try:
        mol = Chem.MolFromSmiles(mol_smiles)
        ecfp = morgan_generator.GetFingerprint(mol)

        return FingerprintRes(ecfp=ecfp.ToBitString())
    except Exception as ex:
        sys.stderr.write(f"Error calc ECFP for ID '{mol_id}':\n" + f"  {ex}\n")
        raise


def process_molecules(opts: Options):
    # Read the input CSV file
    with open(opts.input, "r") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise ValueError("CSV file has no headers")

        errors = []
        if opts.input_id_col not in reader.fieldnames:
            errors.append(f"ID column '{opts.input_id_col}' not found in the CSV file")
        if opts.input_smiles_col not in reader.fieldnames:
            errors.append(
                f"SMILES column '{opts.input_smiles_col}' not found in the CSV file"
            )
        add_col_list = list(vars(add_cols).values())
        for out_col in add_col_list:
            if out_col in reader.fieldnames:
                errors.append(f"'{out_col}' column already exists in the input CSV")
        if len(errors) > 0:
            raise ValueError(
                f"Error in the input CSV file '{opts.input}':\n"
                + "\n".join([f"  {e}" for e in errors])
            )

        output_fields = list(reader.fieldnames) + add_col_list
        with open(opts.output, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=output_fields)
            writer.writeheader()

            morgan_generator = GetMorganGenerator(
                radius=opts.ecfp_radius, fpSize=opts.ecfp_nbits
            )

            for row in reader:
                mol_id = str(row[opts.input_id_col])
                mol_smiles = str(row[opts.input_smiles_col])

                try:
                    fp_res = process_molecule(mol_id, mol_smiles, morgan_generator)
                    output_row = row.copy()
                    output_row.update(
                        {
                            add_cols.ecfp: fp_res.ecfp,
                        }
                    )
                    writer.writerow(output_row)
                except:
                    continue


def main():
    opts = parse_args()
    process_molecules(opts)


if __name__ == "__main__":
    main()
