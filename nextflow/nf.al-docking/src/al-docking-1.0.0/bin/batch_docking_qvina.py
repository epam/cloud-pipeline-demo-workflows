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

add_cols = argparse.Namespace(poses="poses", affinity="affinity")


@dataclass(frozen=True)
class Pose:
    poses: str
    affinity: Union[float, None]


@dataclass(frozen=True)
class Receptor:
    id: str
    pdbqt_fn: str
    config_fn: str
    hash: str = field(init=False)

    def __post_init__(self):
        object.__setattr__(self, "hash", calc_config_hash(self.config_fn))


def calc_config_hash(config_fn: str) -> str:
    with open(config_fn, "r") as f:
        config_content = f.read()
        return hashlib.sha256(config_content.encode("utf-8")).hexdigest()[:6]


@dataclass(frozen=True)
class Options:
    input: str
    input_id_col: str
    input_pdbqt_col: str

    receptor_id: str
    receptor_pdbqt: str

    config: str

    output: str
    poses_pdbqt_dir: str

    cache: Union[str, None]
    seed: Union[int, None]
    cpus: Union[int, None]


def parse_args() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser(description="Batch QVina docking script")
    parser.add_argument(
        "--input", required=True,
        help="Input CSV file with molecule ID and PDBQT file path")
    parser.add_argument(
        "--input-id-col", default="ID", 
        help="Column name for molecule ID (default: ID)")
    parser.add_argument(
        "--input-pdbqt-col", default="PDBQT",
        help="Column name for molecule PDBQT path (default: PDBQT)")
    
    parser.add_argument(
        "--receptor-id", required=True,
        help="Input receptor ID")
    parser.add_argument(
        "--receptor-pdbqt", required=True,
        help="Input receptor PDBQT file")

    parser.add_argument(
        "--config", required=True,
        help="Input config file")
    
    parser.add_argument(
        "--output", required=True, 
        help="Output CSV file with molecule docking scores")
    parser.add_argument(
        "--poses-pdbqt-dir", required=True,
        help="Poses PDBQT files directory")
    
    parser.add_argument(
        "--cache", required=False, default=None,
        help="Cache directory for docking result PDBQT files with poses")
    parser.add_argument(
        "--seed", type=int, required=False, default=None,
        help="Random seed for reproducibility")
    parser.add_argument(
        "--cpus", type=int, required=False, default=None,
        help="CPUs number to use")
    # fmt: on
    return Options(**vars(parser.parse_args()))


@dataclass(frozen=True)
class PosesData:
    affinity: float


qvina_re = re.compile(r"^REMARK VINA RESULT:\s*([-+]?\d+\.\d+)\s+0\.000\s+0\.000")


def parse_poses_file(poses_pdbqt_fn: str) -> Union[float, None]:
    with open(poses_pdbqt_fn, "r") as f:
        for line in f:
            m = qvina_re.match(line)
            if m:
                affinity = float(m.group(1))
                return affinity

    return None


def process_molecule(
    receptor: Receptor,
    mol_id: str,
    ligand_pdbqt_fn: str,
    poses_pdbqt_subdir: str,
    opts: Options,
) -> Pose:
    ligand_pdbqt_fp = ligand_pdbqt_fn
    if not os.path.isabs(ligand_pdbqt_fn):
        ligand_pdbqt_fp = os.path.join(os.path.dirname(opts.input), ligand_pdbqt_fn)

    poses_pdbqt_bfn = f"poses.{mol_id}-in-{receptor.id}-{receptor.hash}.pdbqt"
    tgt_poses_pdbqt_fp = os.path.join(
        opts.poses_pdbqt_dir, poses_pdbqt_subdir, poses_pdbqt_bfn
    )

    cmd_poses_pdbqt_fp = tgt_poses_pdbqt_fp
    if opts.cache:
        cmd_poses_pdbqt_fp = os.path.join(
            opts.cache, poses_pdbqt_subdir, poses_pdbqt_bfn
        )

    if not os.path.exists(cmd_poses_pdbqt_fp):
        try:
            # fmt: off
            cmd = [
                "qvina2.1",
                "--config", receptor.config_fn,
                "--receptor", receptor.pdbqt_fn,
                "--ligand", ligand_pdbqt_fp,
                "--out", cmd_poses_pdbqt_fp,
            ] \
            + (["--seed", str(opts.seed)] if opts.seed is not None else []) \
            + (["--cpu", str(opts.cpus)] if opts.cpus is not None else [])
            # fmt: on
            sys.stdout.write(f"  qvina2.1 cmd: { ' '.join(cmd) }\n")
            result = subprocess.run(
                cmd, check=True, capture_output=False, text=True, timeout=300
            )
            sys.stdout.write(f"completed.\n")

        except Exception as ex:
            sys.stdout.write(f"failed\n")
            sys.stderr.write(
                f"Error docking ID '{mol_id}' into '{receptor.id}':\n" + f"  {ex}\n"
            )
            raise

    if opts.cache:
        os.symlink(cmd_poses_pdbqt_fp, tgt_poses_pdbqt_fp)
    poses_affinity = parse_poses_file(cmd_poses_pdbqt_fp)
    return Pose(
        poses=os.path.relpath(tgt_poses_pdbqt_fp, os.path.dirname(opts.output)),
        affinity=poses_affinity,
    )


def process_molecules(opts: Options):
    receptor = Receptor(
        id=opts.receptor_id,
        pdbqt_fn=opts.receptor_pdbqt,
        config_fn=opts.config,
    )

    poses_pdbqt_subdir = f"{receptor.id}-{receptor.hash}"
    os.makedirs(os.path.join(opts.poses_pdbqt_dir, poses_pdbqt_subdir), exist_ok=True)

    if opts.cache:
        os.makedirs(os.path.join(opts.cache, poses_pdbqt_subdir), exist_ok=True)

    with open(opts.input, "r") as input_f:
        reader = csv.DictReader(input_f)
        if not reader.fieldnames:
            raise ValueError("CSV file has no headers")

        errors = []
        if opts.input_id_col not in reader.fieldnames:
            errors.append(f"ID column '{opts.input_id_col}' not found in the CSV file")
        if opts.input_pdbqt_col not in reader.fieldnames:
            errors.append(
                f"PDBQT column '{opts.input_pdbqt_col}' not found in the CSV file"
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
        with open(opts.output, "w") as output_f:
            writer = csv.DictWriter(output_f, fieldnames=output_fields)
            writer.writeheader()

            row_count = 0
            row_errors = 0
            for row in reader:
                row_count += 1
                mol_id = str(row[opts.input_id_col])
                ligand_pdbqt_fn = str(row[opts.input_pdbqt_col])

                try:
                    docking_res = process_molecule(
                        receptor, mol_id, ligand_pdbqt_fn, poses_pdbqt_subdir, opts
                    )

                    # Create a copy of row and add the Pose attributes
                    output_row = row.copy()
                    output_row.update(
                        {
                            add_cols.poses: docking_res.poses,
                            add_cols.affinity: (
                                f"{docking_res.affinity}"
                                if docking_res.affinity is not None
                                else ""
                            ),
                        }
                    )
                    writer.writerow(output_row)
                except Exception as ex:
                    row_errors += 1

            # if row_errors > (0.2 * row_count):
            #     raise RuntimeError(
            #         f"Too many errors {row_errors} out of {row_count} rows."
            #     )


def main():
    opts = parse_args()
    process_molecules(opts)


if __name__ == "__main__":
    main()
