#!/usr/bin/env python3

import argparse
import csv
from dataclasses import dataclass
import signal
import subprocess
import os
import sys
import tempfile
from typing import Union


@dataclass(frozen=True)
class Options:
    input: str
    input_id_col: str
    input_pdb_col: str

    output: str
    output_pdbqt_col: str
    output_pdbqt_pattern: str

    cache: Union[str, None]


def parse_arguments():
    # fmt: off
    parser = argparse.ArgumentParser(description="Convert PDB to PDBQT using MGLTools prepare_ligand4.py in batch")
    parser.add_argument(
        "--input", required=True, 
        help="Input CSV file with molecule ID and SMILES")
    parser.add_argument(
        "--input-id-col", default="ID", 
        help="Column name for molecule ID (default: ID)")
    parser.add_argument(
        "--input-pdb-col", default="PDB",
        help="Column name for PDB file (relative to CSV)")
    
    parser.add_argument(
        "--output", required=True,
        help="Output CSV file with PDBQT file names")
    parser.add_argument(
        "--output-pdbqt-col", default="PDBQT",
        help="Output CSV file molecule PDBQT file column name (relative to CSV)")
    parser.add_argument(
        "--output-pdbqt-pattern", default="{ID}.pdbqt",
        help="Output PDBQT filename pattern (with {ID})"
    )

    
    parser.add_argument(
        "--cache", required=False, default=None,
        help="Cache directory for PDB files")
    # fmt: on
    return Options(**vars(parser.parse_args()))


def process_molecule(mol_id: str, pdb_fn: str, pdbqt_fn: str, opts: Options):
    pdb_fp = pdb_fn
    if not os.path.isabs(pdb_fn):
        pdb_fp = os.path.join(os.path.dirname(opts.input), pdb_fn)

    pdbqt_bfn = os.path.basename(pdbqt_fn)

    tgt_pdbqt_fp = pdbqt_fn
    if not os.path.isabs(pdbqt_fn):
        tgt_pdbqt_fp = os.path.join(os.path.dirname(opts.input), pdbqt_fn)

    cmd_pdbqt_fp = tgt_pdbqt_fp
    if opts.cache:
        cmd_pdbqt_fp = os.path.join(opts.cache, pdbqt_bfn)

    # Check if the output file already exists
    if not os.path.exists(cmd_pdbqt_fp):
        sys.stdout.write(
            f"File '{cmd_pdbqt_fp}' not found. Run prepare_ligand4.py...\n"
        )

        cwd_pdb_tf = tempfile.NamedTemporaryFile(
            mode="w",
            delete=True,
            dir=".",
            prefix=f"ligand.{mol_id}.",
            suffix="-tmp.pdb",
        )
        cwd_pdb_tf.close()
        os.symlink(pdb_fp, cwd_pdb_tf.name)
        try:
            # fmt:off
            cmd = [
                "conda", "run", "-n", "mgltools", 
                "prepare_ligand4.py", "-l", cwd_pdb_tf.name, "-o", cmd_pdbqt_fp
            ]
            # fmt: on
            sys.stdout.write(f"  prepare_ligand4.py cmd: { ' '.join(cmd) }\n")
            result = subprocess.run(
                    " ".join(cmd),
                    check=True,
                capture_output=False,
                    text=True,
                    shell=True,
                    timeout=120,
                )
            sys.stdout.write(f"completed.\n")
        except Exception as ex:
            open(cmd_pdbqt_fp, "w").close()  # creates or clears existing
            sys.stdout.write(f"failed\n")
            sys.stderr.write(
                f"Error prepare_ligand4.py for ID '{mol_id}':\n" + f"  {ex}\n"
            )
        finally:
            os.unlink(cwd_pdb_tf.name)

    if opts.cache:
        os.symlink(cmd_pdbqt_fp, tgt_pdbqt_fp)
        sys.stdout.write("Link from cache to PDBQT file created.\n")


def process_molecules(opts: Options):
    # Read the input CSV file
    with open(opts.input, "r") as input_f:
        reader = csv.DictReader(input_f)
        if not reader.fieldnames:
            raise ValueError("CSV file has no headers")

        errors = []
        if opts.input_id_col not in reader.fieldnames:
            errors.append(f"ID column '{opts.input_id_col}' not found in the CSV file")
        if opts.input_pdb_col not in reader.fieldnames:
            errors.append(
                f"PDB column '{opts.input_pdb_col}' not found in the CSV file"
            )
        add_col_list = [opts.output_pdbqt_col]
        for out_col in add_col_list:
            if out_col in reader.fieldnames:
                errors.append(f"'{out_col}' column already exists in the input CSV")
        if len(errors) > 0:
            raise ValueError(
                f"Error in the input CSV file '{opts.input}':\n"
                + "\n".join([f"  {e}" for e in errors])
            )

        output_fields = list(reader.fieldnames) + add_col_list
        with open(opts.output, "w", newline="") as output_f:
            writer = csv.DictWriter(output_f, fieldnames=output_fields)
            writer.writeheader()

            for row in reader:
                mol_id = str(row[opts.input_id_col])
                # mol_smiles = str(row[opts.input_smiles_col])
                pdb_fn = str(row[opts.input_pdb_col])
                sys.stdout.write(f"###### row: {row}\n")

                pdbqt_fn = opts.output_pdbqt_pattern.format(ID=mol_id)
                process_molecule(mol_id, pdb_fn, pdbqt_fn, opts)

                output_row = row.copy()
                output_row[opts.output_pdbqt_col] = pdbqt_fn
                writer.writerow(output_row)


def main():
    opts = parse_arguments()
    process_molecules(opts)


if __name__ == "__main__":
    main()
