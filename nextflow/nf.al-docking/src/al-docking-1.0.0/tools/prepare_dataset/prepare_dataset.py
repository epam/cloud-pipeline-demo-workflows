#!/usr/bin/env python3
"""
prepare_dataset.py: Prepares a subset of small molecules for model training with uniform affinity distribution.
"""
import argparse
from dataclasses import dataclass
import logging
import re
from pathlib import Path

import numpy as np
import pandas as pd
from tqdm import tqdm
import matplotlib.pyplot as plt

@dataclass(frozen=True)
class Options:
    db: str
    poses: str
    size: int
    output: str

def parse_args() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser(
        description='Prepare a molecule subset with uniform affinity distribution.'
    )
    parser.add_argument('--db', required=True, help='CSV file with molecule list (columns: ID, SMILES)')
    parser.add_argument('--poses', required=True, help='Directory with molecule pose pdbqt files')
    parser.add_argument('--size', type=int, required=True, help='Subset size')
    parser.add_argument('--output', required=True, help='Output CSV filename')
    # fmt: on
    return Options(**vars(parser.parse_args()))

filename_re = re.compile(r'^(?:.*\.)?(?P<id>[^-]+)-in-.*\.pdbqt$')
qvina_re = re.compile(r"^REMARK VINA RESULT:\s*([-+]?\d+\.\d+)\s+0\.000\s+0\.000", re.MULTILINE)

def extract_affinities(opts:Options) -> pd.DataFrame:
    """
    Extract affinities from REMARK VINA RESULT lines in pdbqt files.
    Returns a DataFrame with columns [ID, affinity].
    """

    # Save cache of extracted affinities
    affinities_cache_fn = Path(opts.output).with_name(Path(opts.output).stem + '-cache-affinity.csv')
    # if file exists, load it
    if affinities_cache_fn.exists():
        logging.info('Loading cached affinities from %s', affinities_cache_fn)
        aff_df = pd.read_csv(affinities_cache_fn, dtype={'ID': str})
        return aff_df
    
    else:
        record_list = []
        for pfile in tqdm(Path(opts.poses).glob('*.pdbqt'), desc='Extracting affinities'):
            fn_m = filename_re.match(pfile.name)
            if not fn_m:
                logging.warning(f'Unrecognized filename: {pfile.name}')
                continue
            mol_id = fn_m.group('id')
            affinity = None
            with pfile.open() as f:
                file_cnt = f.read()
                aff_m = qvina_re.search(file_cnt)
                if aff_m:
                    try:
                        affinity = float(aff_m.group(1))
                    except ValueError:
                        logging.warning(f'Failed to parse affinity from regex in {pfile.name}')
            if affinity is not None:
                record_list.append({'ID': mol_id, 'affinity': affinity})
            else:
                logging.warning(f'Affinity not found for {pfile.name}')
        aff_df = pd.DataFrame(record_list)
        aff_df.to_csv(affinities_cache_fn, index=False)
        logging.info('Extracted affinities cached to %s', affinities_cache_fn)
        return aff_df


def sample_uniform(df: pd.DataFrame, size: int) -> pd.DataFrame:
    """
    Selects `size` records with a distribution as close to uniform over `affinity`.
    Splits affinities into 20 equal bins (-20 to 0), then allocates samples per bin
    starting from the least populated bin and redistributing any shortages.
    """
    # Bin affinities between -20 and 0 into 20 bins
    num_bins = 20
    bins = np.linspace(-20, 0, num_bins + 1)
    affinities = df['affinity'].to_numpy(dtype=float)
    bin_indices = np.digitize(affinities, bins, right=False) - 1
    # Group row indices by bin
    bin_groups = {i: df.index[bin_indices == i].tolist() for i in range(num_bins)}
    # Sort bins by increasing population
    remaining_bins = sorted(bin_groups.keys(), key=lambda i: len(bin_groups[i]))
    selected_idxs = []
    remaining = size
    # Iteratively sample per bin
    for bin_i in remaining_bins:
        bins_left = len(remaining_bins)
        req = remaining // bins_left
        extra = remaining % bins_left
        # Allocate extra one by one to current bins
        want = req + (1 if extra > 0 else 0)
        if extra > 0:
            extra -= 1
        avail = bin_groups[bin_i]
        take = min(len(avail), want)
        if take > 0:
            chosen = np.random.choice(avail, size=take, replace=False).tolist()
            selected_idxs.extend(chosen)
        remaining -= take
        # Remove processed bin
        remaining_bins = remaining_bins[1:]
        if remaining <= 0:
            break
    # Return sampled DataFrame
    return df.loc[selected_idxs].reset_index(drop=True)


def main(opts: Options):
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

    logging.info('Extracting affinities from %s', opts.poses)
    aff_df = extract_affinities(opts)
    logging.info('Found affinities for %d molecules', len(aff_df))
    
    logging.info('Reading database %s', opts.db)
    db_df = pd.read_csv(opts.db, dtype={'ID': str})
    merged_df = pd.merge(db_df, aff_df, on='ID', how='inner')
    logging.info('After merge, %d molecules remain', len(merged_df))

    # Sample subset including affinity
    selected_df = sample_uniform(merged_df[['ID', 'SMILES', 'affinity']], opts.size)
    logging.info('Selected %d molecules for subset', len(selected_df))

    # Filter out only the affinity column before saving
    output_df = selected_df[[col for col in selected_df.columns if col != 'affinity']]
    output_df.to_csv(opts.output, index=False)
    logging.info('Subset saved to %s (without affinity column)', opts.output)

    # Plot histogram: original distribution (normalized, gray) under selected subset counts
    plt.figure()
    plt.hist(merged_df['affinity'], bins=20, density=True, color='gray', alpha=0.5, label='Original')
    plt.hist(selected_df['affinity'], bins=20, density=True, color='green', alpha=0.5, edgecolor='black', label='Selected')
    plt.title('Affinity Distribution: Original vs Selected')
    plt.xlabel('Affinity')
    plt.ylabel('Relative Frequency')
    plt.xlim(-20, 0)
    plt.legend()
    hist_path = Path(opts.output).with_suffix('.png')
    plt.savefig(hist_path)
    logging.info('Histogram saved to %s', hist_path)


if __name__ == '__main__':
    print(f"Arguments")
    opts = parse_args()
    for k, v in vars(opts).items():
        print(f"{k}: {v}")
    main(opts)
