#!/usr/bin/env python3
"""
Filter calculation cache by molecule IDs.
"""

import argparse
import csv
import os
import sys
from dataclasses import dataclass
from typing import List, Dict, Tuple
from tqdm import tqdm

@dataclass(frozen=True)
class Options:
    input: str
    input_id_col: str
    input_cache_dir: str
    patterns: List[str]
    output_cache_dir: str


def parse_args() -> Options:
    parser = argparse.ArgumentParser(description="Filter calculation cache by molecule IDs")
    parser.add_argument('--input', required=True,
                        help="CSV file containing molecule list")
    parser.add_argument('--input-id-col', required=True,
                        help="Column name for molecule IDs in the input CSV")
    parser.add_argument('--input-cache-dir', required=True,
                        help="Path to the input cache directory")
    parser.add_argument('--pattern', dest='patterns', action='append', required=True,
                        help="File pattern with {ID} placeholder; can be provided multiple times")
    parser.add_argument('--output-cache-dir', required=True,
                        help="Directory for the filtered cache")
    args = parser.parse_args()
    return Options(
        input=args.input,
        input_id_col=args.input_id_col,
        input_cache_dir=args.input_cache_dir,
        patterns=args.patterns,
        output_cache_dir=args.output_cache_dir
    )

def read_ids(csv_file: str, id_col: str) -> List[str]:
    """Read molecule IDs from a CSV file."""
    ids: List[str] = []
    with open(csv_file, newline='') as f:
        reader = csv.DictReader(f)
        if id_col not in reader.fieldnames:
            print(f"Error: column '{id_col}' not found in {csv_file}", file=sys.stderr)
            sys.exit(1)
        for row in reader:
            ids.append(row[id_col])
    return ids

def main():
    """Main execution function."""
    opts = parse_args()
    ids = read_ids(opts.input, opts.input_id_col)
    found_by_pattern: Dict[str, List[Tuple[str, str]]] = {}

    for pattern in opts.patterns:
        found: List[Tuple[str, str]] = []
        print(f"Checking pattern '{pattern}':")
        for id_val in tqdm(ids, unit="ID"):
            rel_path = pattern.format(ID=id_val)
            full_path = os.path.join(opts.input_cache_dir, rel_path)
            if os.path.exists(full_path):
                found.append((rel_path, full_path))
        found_by_pattern[pattern] = found
    for pattern in opts.patterns:
        print(f"Pattern '{pattern}': found {len(found)} files")

    response = input("Create filtered cache with symbolic links? [y/N]: ")
    if response.lower() != 'y':
        print("Aborted.")
        sys.exit(0)

    # Create symbolic links for found files
    for _, files in found_by_pattern.items():
        for rel_path, src_path in files:
            dest_path = os.path.join(opts.output_cache_dir, rel_path)
            dest_dir = os.path.dirname(dest_path)
            os.makedirs(dest_dir, exist_ok=True)
            try:
                os.symlink(src_path, dest_path)
            except FileExistsError:
                pass

    print("Filtered cache created.")

if __name__ == "__main__":
    main()
