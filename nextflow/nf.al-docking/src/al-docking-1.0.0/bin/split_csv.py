#!/usr/bin/env python3

import argparse
import csv
import os
import random
from pathlib import Path
import sys

from dataclasses import dataclass
from typing import List, Union


@dataclass(frozen=True)
class Options:
    input: str
    part_list: List[str]
    part_size_list: List[int]
    remain: str
    seed: Union[int, None]

    def __post_init__(self):
        if len(self.part_list) != len(self.part_size_list):
            raise ValueError(
                f"Number of '--part' ({len(self.part_list)}) must match "
                + f"number of '--part-size' ({len(self.part_size_list)})"
            )


def parse_arguments():
    # fmt: off
    parser = argparse.ArgumentParser(description="Split a CSV file into parts of specified size.")
    parser.add_argument(
        "--input", required=True, 
        help="Input CSV file")
    parser.add_argument(
        "--part", dest="part_list", action="append", type=str,  required=True, 
        help="Output CSV part file name (can be specified multiple times)")
    parser.add_argument(
        "--part-size", dest="part_size_list", action="append", type=int, required=True,
        help="Output CSV part size number of rows (for each part)")
    parser.add_argument(
        "--remain", 
        help="File for remaining rows")
    parser.add_argument(
        "--seed", type=int, 
        help="Random seed for reproducibility")
    # fmt: on

    return parser.parse_args()


def split_csv(opts: Options):
    if opts.seed is not None:
        sys.stdout.write(f"Set seed for random: { opts.seed }\n")
        random.seed(opts.seed)

    input_path = Path(opts.input)

    # Read header and count rows
    with open(input_path, "r") as input_f:
        input_csvr = csv.reader(input_f)
        header = next(input_csvr)  # Get header
        input_rows: List[List[str]] = list(input_csvr)

        # Process data based on parameters
        if opts.remain:
            # Create first part with specified size
            split_part_and_remain(
                opts.part_list, opts.part_size_list, opts.remain, input_rows, header
            )

        else:
            split_into_parts(
                opts.input,
                opts.part_list[0],
                opts.part_size_list[0],
                input_path,
                input_rows,
                header,
            )


def split_part_and_remain(
    part_fn_list: List[str],
    part_size_list: List[int],
    remain_fn: str,
    input_rows: List[List[str]],
    header: List[str],
) -> None:
    random.shuffle(input_rows)
    offset = 0
    for part_fn, part_size in zip(part_fn_list, part_size_list):
        with open(part_fn, "w") as part_f:
            part_csvw = csv.writer(part_f)
            part_csvw.writerow(header)
            for i in range(part_size):
                if (offset + i) >= len(input_rows):
                    break
                part_csvw.writerow(input_rows[offset + i])
            offset += part_size

    with open(remain_fn, "w") as remain_f:
        remain_csvw = csv.writer(remain_f)
        remain_csvw.writerow(header)
        for i in range(offset, len(input_rows)):
            remain_csvw.writerow(input_rows[i])


def split_into_parts(
    input, part_fn: str, part_size: int, input_path: Path, csvfile, reader
):
    # Count rows to determine number of parts

    raise NotImplementedError("Not ready yet")

    csvfile.seek(0)
    next(reader)  # Skip header
    row_count = sum(1 for _ in reader)
    num_parts = (row_count + part_size - 1) // part_size  # Ceiling division

    # Create multiple part files
    with open(input_path, "r", newline="") as csvfile:
        reader = csv.reader(csvfile)
        header_row = next(reader)  # Skip header

        for part_num in range(num_parts):
            part_filename = f"{part_fn}_{part_num:08d}"
            with open(part_filename, "w", newline="") as part_file:
                writer = csv.writer(part_file)
                writer.writerow(header_row)

                for _ in range(part_size):
                    try:
                        row = next(reader)
                        writer.writerow(row)
                    except StopIteration:
                        break

            print(f"Created file {part_filename}")

    print(f"Split {input} into {num_parts} parts")


def main():
    args = parse_arguments()
    split_csv(Options(**vars(args)))


if __name__ == "__main__":
    main()
