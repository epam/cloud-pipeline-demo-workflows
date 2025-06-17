#!/usr/bin/env python3

import os
from types import SimpleNamespace
from typing import List, Union, Literal
import argparse
import re
from pathlib import Path
import numpy as np
from Bio import PDB


class LigandDesc:
    def __init__(self, resname: str, chain: Union[str, None], resnum: Union[int, None]):
        self.resname = resname
        self.chain = chain
        self.resnum = resnum

    def accept_residue(self, residue) -> bool:
        return (
            (self.resname is None or self.resname == residue.get_resname())
            and (self.chain is None or self.chain == residue.get_parent().id)
            and (self.resnum is None or self.resnum == residue.get_id()[1])
        )

    def __str__(self) -> str:
        return f"{self.resname}-{self.chain}-{self.resnum}"

    def __repr__(self):
        return f"{self.resname} {self.chain} {self.resnum}"


class SiteData:
    def __init__(
        self, writer: PDB.PDBIO, select: PDB.Select, ligand_desc: LigandDesc = None
    ):
        self.writer = writer
        self.select = select
        self.ligand_desc = ligand_desc

    def save(self, file):
        self.writer.save(file, self.select)


class LigandSelect(PDB.Select):
    def __init__(self, ligand_desc: LigandDesc):
        super().__init__()
        self.ligand_desc = ligand_desc

    def accept_residue(self, residue) -> Literal[1]:
        res = self.ligand_desc.accept_residue(residue)
        return 1 if res else 0  # type: ignore


class ReceptorSelect(PDB.Select):
    def __init__(self, ligand_desc_list: List[LigandDesc]):
        super().__init__()
        self.ligand_desc_list = ligand_desc_list

    def accept_residue(self, residue) -> Literal[1]:
        """Accept all residues that do not belong to any ligand in the list."""
        accept_residure_res = True
        for ligand_desc in self.ligand_desc_list:
            if ligand_desc.accept_residue(residue):
                accept_residure_res = False
                break
        return 1 if accept_residure_res else 0  # type: ignore


def extract_binding_sites(pdb_file) -> List[LigandDesc]:
    """Extract binding site information from PDB REMARK 800 lines and HET records."""
    sites = []
    with open(pdb_file) as f:
        for line in f:
            # Parse REMARK 800 lines
            # http://www.bmsc.washington.edu/CrystaLinks/man/pdb/part_31.html
            if line.startswith("REMARK 800 SITE_DESCRIPTION:"):
                match = re.search(r"BINDING SITE FOR RESIDUE (\w+) ([A-Z]) (\d+)", line)
                if match:
                    resname, chain, resnum = match.groups()
                    sites.append(LigandDesc(resname, chain, int(resnum)))
            
            # Parse HET records according to PDB fixed width format
            # https://www.wwpdb.org/documentation/file-format-content/format33/sect4.html
            elif line.startswith("HET   "):
                try:
                    resname = line[7:10].strip()  # columns 8-10
                    chain = line[12]  # column 13
                    # Parse the sequence number, handling potential insertion code
                    resnum_str = line[13:17].strip()  # columns 14-17
                    # Extract just the digits for the residue number
                    resnum = int(''.join(c for c in resnum_str if c.isdigit()))
                    sites.append(LigandDesc(resname, chain, resnum))
                except (ValueError, IndexError):
                    continue  # Skip malformed HET records
    
    return sites


def split_pdb(src_path: Path, ligand_list: List[LigandDesc]):
    """Split PDB file into receptor and ligand files based on residue info."""
    parser = PDB.PDBParser(QUIET=False)
    structure = parser.get_structure("structure", str(src_path))

    # Create writers
    ligand_writer = PDB.PDBIO()

    receptor_writer = PDB.PDBIO()
    receptor_writer.set_structure(structure)

    def build_ligand_writer(ligand_desc: LigandDesc, structure):
        ligand_writer = PDB.PDBIO()
        ligand_writer.set_structure(structure)
        return SiteData(ligand_writer, LigandSelect(ligand_desc), ligand_desc)

    return SimpleNamespace(
        receptor=SiteData(receptor_writer, ReceptorSelect(ligand_list)),
        ligands=[
            build_ligand_writer(ligand_desc, structure) for ligand_desc in ligand_list
        ],
    )


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Process PDB file to split receptor and ligand, and calculate binding site dimensions."
    )
    parser.add_argument("source_pdb", help="Source PDB file")
    parser.add_argument("--resname", help="Residue name (e.g., STI)", required=False)
    parser.add_argument("--resnum", type=int, help="Residue number", required=False)
    
    return parser.parse_args()

def main():
    """Process PDB file to split receptor and ligand, and calculate binding site dimensions."""
    opts = parse_arguments()
    
    source_pdb = opts.source_pdb
    resname = opts.resname
    resnum = opts.resnum

    # If resname is not provided, try to get from REMARK 800
    if not all([resname, resnum]):
        sites = extract_binding_sites(source_pdb)
        if not sites:
            raise Exception(
                "No binding sites found in REMARK 800 and no residue info provided"
            )
    else:
        sites = [LigandDesc(resname, None, resnum)]

    basename = os.path.splitext(os.path.basename(source_pdb))[0]
    src_path = Path(source_pdb)
    out_receptor_pdb_fn = src_path.parent / f"{basename}.wo-ligand.pdb"

    try:
        pdb_parts = split_pdb(src_path, sites)
        pdb_parts.receptor.save(str(out_receptor_pdb_fn))

        ligand_data: SiteData
        for ligand_data in pdb_parts.ligands:  #
            out_ligand_pdb_fn = (
                src_path.parent / f"{basename}.{ligand_data.ligand_desc}.pdb"
            )
            ligand_data.save(str(out_ligand_pdb_fn))

            # Get all atom coordinates for this ligand
            atoms = list(ligand_data.writer.structure.get_atoms())
            if not atoms:            print(
                f"Warning: No atoms found for ligand {ligand_data.ligand_desc}"
            )
                continue

            # Extract coordinates
            coords = np.array([atom.get_coord() for atom in atoms])

            # Calculate min, max, center, and size for each dimension
            min_coords = np.min(coords, axis=0)
            max_coords = np.max(coords, axis=0)
            center = (min_coords + max_coords) / 2
            size = max_coords - min_coords

            out_ligand_config_fn = (
                src_path.parent / f"{basename}.{ligand_data.ligand_desc}.config"
            )
            with open(out_ligand_config_fn, "w") as cfg_f:
                # Write Vina configuration
                cfg_f.write(f"receptor = {out_receptor_pdb_fn.name}\n\n")
                cfg_f.write(f"center_x = {center[0]:.3f}\n")
                cfg_f.write(f"center_y = {center[1]:.3f}\n")
                cfg_f.write(f"center_z = {center[2]:.3f}\n\n")
                cfg_f.write(f"size_x = {size[0]*1.2:.3f}\n")
                cfg_f.write(f"size_y = {size[1]*1.2:.3f}\n")
                cfg_f.write(f"size_z = {size[2]*1.2:.3f}\n")

            click.echo(f"Ligand config: {out_ligand_config_fn}")

    except Exception as ex:
        raise click.ClickException(str(ex))


if __name__ == "__main__":
    main()
