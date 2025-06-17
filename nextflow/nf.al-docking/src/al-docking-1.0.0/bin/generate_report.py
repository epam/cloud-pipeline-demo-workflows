#!/usr/bin/env python3

import argparse
from dataclasses import dataclass
from glob import glob
import logging
import os
import re
from pathlib import Path

import numpy as np
import pandas as pd
from tqdm import tqdm
import matplotlib.pyplot as plt
import json
import base64
import jinja2

@dataclass(frozen=True)
class Options:
    template: str
    data_dir: str
    receptor: str
    params_json: str
    figures_dir: str
    output: str

def main(opts: Options):
    # Determine analysis directories
    iterations_path = Path(opts.data_dir)
    analysis_dir = iterations_path.parent

    # Load the latest parameters JSON
    params_files = sorted(glob(opts.params_json))
    if not params_files:
        logging.warning(f"Params .json file '{opts.params_json}' not found.")
        params = {}
    else:
        with open(params_files[-1], 'r') as pf:
            params = json.load(pf)

    # Collect figures based on receptor name
    figure_file_name_list = [
        f"fig01-{opts.receptor}-rmse_residuals.png",
        f"fig02-{opts.receptor}-r2.png",
        f"fig03-{opts.receptor}-uncertainty.png",
        f"fig04-{opts.receptor}-train_top_affinity.png",
        # f"fig05-{opts.receptor}-validation_residuals.png",
        # f"fig06-{opts.receptor}-training_residuals.png",
    ]
    figures = []
    for fig_fn in figure_file_name_list:
        fig_fp = os.path.join(opts.figures_dir, fig_fn)
        if os.path.exists(fig_fp):
            with open(fig_fp, 'rb') as fig_f:
                raw = fig_f.read()
                b64 = base64.b64encode(raw).decode('utf-8')
                figures.append({'title': Path(fig_fn).stem, 'data': f"data:image/png;base64,{b64}"})
        else:
            logging.warning(f"Figure file not found: {fig_fp}")

    # Load and render Jinja2 template
    template_src = Path(opts.template).read_text()
    template = jinja2.Template(template_src)
    html = template.render(
        receptor=opts.receptor,
        params_json=json.dumps(params, indent=2),
        figures=figures
    )

    # Write output HTML
    out_path = Path(opts.output)
    out_path.write_text(html)
    print(f"Report written to {out_path}")

def parse_args() -> Options:
    #fmt: off
    parser = argparse.ArgumentParser(
        description='Generate HTML report for receptor breakdown analysis.'
    )
    parser.add_argument(
        '--template', type=str, required=True,
        help='Path to the Jinja2 HTML template file')
    parser.add_argument(
        '--data-dir', dest="data_dir", type=str, required=True,
        help='Path to the directory containing active learning iterations results.')
    parser.add_argument(
        '--receptor', type=str, required=True, 
        help='Receptor name')
    parser.add_argument(
        '--params-json', dest="params_json", type=str, required=True,
        help='Path to the parameters JSON file')
    parser.add_argument(
        '--figures-dir', dest="figures_dir", type=str, required=True,
        help='Path to the directory containing figures.')
    parser.add_argument(
        '--output', required=True,
        help='Output report HTML filename')
    # fmt: on
    return Options(**vars(parser.parse_args()))

if __name__ == "__main__":
    print("Arguments")
    opts = parse_args()
    for k, v in vars(opts).items():
        print(f"{k}: {v}")
    main(opts)


