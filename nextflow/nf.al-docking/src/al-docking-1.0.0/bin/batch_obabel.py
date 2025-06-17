#!/usr/bin/env python3

import argparse
import csv
from dataclasses import dataclass
import subprocess
import os
import sys
from typing import TypedDict


@dataclass(frozen=True)
class Options:
    input: str
    input_id_col: str
    input_smiles_col: str

    output: str
    output_pdb_col: str
    output_pdb_pattern: str

    gen3d: bool
    d: bool

    cache: str


def parse_arguments() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser(description="Convert SMILES to PDB using OpenBabel in batch")
    parser.add_argument(
        "--input", required=True, 
        help="Input CSV file with molecule ID and SMILES")
    parser.add_argument(
        "--input-id-col", default="ID", 
        help="Input CSV file molecule ID column name")
    parser.add_argument(
        "--input-smiles-col", default="SMILES", 
        help="Input CSV file molecule SMILES column name")
    
    parser.add_argument(
        "--output", required=True,
        help="Output CSV file with PDB file names")
    parser.add_argument(
        "--output-pdb-col", default="PDB",
        help="Output CSV file molecule PDB file column name (relative to CSV)")
    parser.add_argument(
        "--output-pdb-pattern", default="{ID}.pdb",
        help="Output PDB filename pattern (with {ID})"
    )
    
    parser.add_argument(
        "--gen3d", action="store_true", 
        help="obabel: Generate 3D coordinates")
    parser.add_argument(
        "-d", action="store_true", 
        help="obabel: dehydrogenate")
    
    parser.add_argument(
        "--cache", required=False, default=None,
        help="Cache directory for PDB files")
    # fmt: on

    return Options(**vars(parser.parse_args()))


def process_molecule(mol_id, mol_smiles: str, pdb_fn: str, opts: Options):
    pdb_bfn = os.path.basename(pdb_fn)

    tgt_pdb_fp = pdb_fn
    if not os.path.isabs(pdb_fn):
        tgt_pdb_fp = os.path.join(os.path.dirname(opts.input), pdb_fn)

    cmd_pdb_fp = tgt_pdb_fp
    if opts.cache:
        cmd_pdb_fp = os.path.join(opts.cache, pdb_bfn)

    if not os.path.exists(cmd_pdb_fp):
        sys.stdout.write(f"File '{cmd_pdb_fp}' not found. Run obabel...\n")
        try:
            # fmt:off
            cmd = [
                "obabel",
                f"-:{mol_smiles}",
                "-i", "smiles",
                "--title", mol_id,
                "-o", "pdb" ] \
                + (["--gen3d"] if opts.gen3d else []) \
                + (["-d"] if opts.d else []) \
                + (["-O", cmd_pdb_fp])
            # fmt: on
            sys.stdout.write(f"  obabel cmd: { ' '.join(cmd) }\n")
            result = subprocess.run(cmd, check=True, capture_output=False, text=True, timeout=60)
            sys.stdout.write(f"completed.\n")
        except Exception as ex:
            sys.stdout.write(f"failed\n")
            sys.stderr.write(
                f"Error converting SMILES '{mol_smiles}' for ID '{mol_id}':\n"
                + f"  {ex}\n"
            )
            raise

    if opts.cache:
        os.symlink(cmd_pdb_fp, tgt_pdb_fp)
        sys.stdout.write("Link from cache to PDB file created.")


def process_input(opts: Options):
    with open(opts.input, "r") as file:
        reader = csv.DictReader(file)

        if not reader.fieldnames:
            raise ValueError("CSV file has no headers")

        errors = []
        if opts.input_id_col not in reader.fieldnames:
            errors.append(f"ID column '{opts.input_id_col}' not found in the input CSV")
        if opts.input_smiles_col not in reader.fieldnames:
            errors.append(
                f"SMILES column '{opts.input_smiles_col}' not found in the input CSV"
            )
        add_col_list = [opts.output_pdb_col]
        for out_col in add_col_list:
            if out_col in reader.fieldnames:
                errors.append(f"'{out_col}' column already exists in the input CSV")
        if len(errors) > 0:
            raise ValueError(
                "Errors in input CSV file '{opts.input}':\n"
                + "\n".join([f"  {e}" for e in errors])
            )

        output_fields = list(reader.fieldnames) + add_col_list
        with open(opts.output, "w", newline="") as output_f:
            writer = csv.DictWriter(output_f, fieldnames=output_fields)
            writer.writeheader()

            for row in reader:
                mol_id = str(row[opts.input_id_col])
                mol_smiles = str(row[opts.input_smiles_col])

                try:
                    if (
                        not mol_smiles
                        or mol_smiles.strip().lower() == "nan"
                        or mol_smiles.strip() == ""
                    ):
                        raise ValueError(f"Empty or invalid SMILES of '{mol_id}'.")

                    pdb_fn = opts.output_pdb_pattern.format(ID=mol_id)
                    process_molecule(mol_id, mol_smiles, pdb_fn, opts)

                    output_row = row.copy()
                    output_row[opts.output_pdb_col] = pdb_fn
                    writer.writerow(output_row)
                except:
                    continue


def main():
    opts = parse_arguments()
    process_input(opts)


if __name__ == "__main__":
    main()
