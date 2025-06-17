#!/usr/bin/env python3

from dataclasses import dataclass
import os
import sys
import random
import argparse

# use Enum for method choices
from enum import Enum
import pandas as pd

script_dir = os.path.dirname(os.path.abspath(os.path.realpath(__file__)))
if script_dir not in sys.path:
    sys.path.append(script_dir)

from libs.utils import set_seed


class Methods(Enum):
    GREEDY = "greedy"
    UCB = "ucb"
    UNC = "unc"


class Columns(Enum):
    # ID = 'ID'
    # SMILES = 'SMILES'
    PRED = "Pred"
    UNC = "Unc"
    UCB = "Ucb"


@dataclass(frozen=True)
class Options:
    title: str
    input: str
    method: Methods
    output_size: int
    output: str
    remain: str
    seed: int


def edit_active_learning_dataset(
    title: str,
    input: str,
    method: Methods,
    output_size: int,
    output: str,
    remain: str,
):
    input_df = pd.read_csv(input)

    # df_output = pd.read_csv(output)
    # df_remain = pd.read_csv(remain)
    pred_list = list(input_df[Columns.PRED.value])
    unc_list = list(input_df[Columns.UNC.value])
    ucb_list = [pred_list[i] - 2.0 * unc_list[i] for i in range(len(input_df))]
    input_df[Columns.UCB.value] = ucb_list

    if method == Methods.GREEDY.value:
        input_df = input_df.sort_values(by=[Columns.PRED.value])
    elif method == Methods.UCB.value:
        input_df = input_df.sort_values(by=[Columns.UCB.value])
    elif method == Methods.UNC.value:
        input_df = input_df.sort_values(by=[Columns.UNC.value], ascending=False)
    else:
        raise ValueError(f"Unknown method: {method}")

    cols = {col.value for col in Columns}
    output_df = input_df[:output_size]
    output_df = output_df[[col for col in output_df.columns if col not in cols]]

    remain_df = input_df[output_size:]
    remain_df = remain_df[[col for col in output_df.columns if col not in cols]]

    output_df.to_csv(output, index=False)
    remain_df.to_csv(remain, index=False)


def main(args: Options):
    set_seed(seed=args.seed)
    edit_active_learning_dataset(
        title=args.title,
        input=args.input,
        method=args.method,
        output_size=args.output_size,
        output=args.output,
        remain=args.remain,
    )


def parse_args() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--title', type=str, required=True, 
        help='Job title of this execution')
    parser.add_argument(
        '--input', type=str, required=True, 
        help='')
    parser.add_argument(
        '--seed', type=int, required=True, 
        help='Seed used for dataset splitting')
    parser.add_argument(
        '--method', type=str, required=True, 
        help='')

    parser.add_argument(
        '--output_size', type=int, default=1000, 
        help='')
    parser.add_argument(
        '--output', type=str,
        help="Output train sample CSV file name")
    parser.add_argument(
        '--remain', type=str,
        help="Remain sample CSV file name")
    return Options(**vars(parser.parse_args()))


if __name__ == "__main__":
    print(f"Arguments")
    opts = parse_args()
    for k, v in vars(opts).items():
        print(f"{k}: {v}")
    main(opts)
