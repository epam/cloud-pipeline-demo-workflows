#!/usr/bin/env python3

from dataclasses import dataclass
from enum import Enum
import os
import sys
import argparse
import glob
from typing import Any, Dict, List, Union

import pandas as pd
import numpy as np
from sklearn.metrics import mean_squared_error, r2_score
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator


@dataclass(frozen=True)
class Options:
    receptor: str
    data_dir: str
    max_iteration_num: int
    out_dir: str


class SampleTypes(Enum):
    """Types of samples used in the analysis."""

    VALID_BEFORE = "valid_before"
    VALID = "valid"
    TRAIN_BEFORE = "train_before"
    TRAIN = "train"
    TEST_BEFORE = "test_before"
    TEST = "test"


class Stats(Enum):
    """Keys for statistics computed on data."""

    ITERS = "iters"
    RMSE = "rmse"
    R2_TEST = "r2_test"
    R2_VALID = "r2_valid"
    R2_TRAIN = "r2_train"
    RESIDUALS_TEST = "residuals_test"
    RESIDUALS_VALID_BEFORE = "residuals_valid_before"
    RESIDUALS_VALID = "residuals_valid"
    RESIDUALS_TRAIN_BEFORE = "residuals_train_before"
    RESIDUALS_TRAIN = "residuals_train"
    UNCERTAINTY = "uncertainty"
    TRAIN_TOP_AFFINITY = "top100_affinity"


data_file_name_patterns = {
    SampleTypes.VALID_BEFORE: "validation-{receptor}.pdb.pdbqt.docked.before-inferred.csv",
    SampleTypes.VALID: "validation-{receptor}.pdb.pdbqt.docked.inferred.csv",
    SampleTypes.TRAIN_BEFORE: "{receptor}-{iter:04d}.train.pdb.pdbqt.docked.before-inferred.csv",
    SampleTypes.TRAIN: "{receptor}-{iter:04d}.train.pdb.pdbqt.docked.inferred.csv",
    SampleTypes.TEST_BEFORE: "{receptor}-{iter:04d}.test.pdb.pdbqt.docked.before-inferred.csv",
    SampleTypes.TEST: "{receptor}-{iter:04d}.test.pdb.pdbqt.docked.inferred.csv",
}


def find_data_files(data_dir, receptor, iter: int, sample_type: SampleTypes) -> str:
    """Return sorted list of inferred CSVs for a receptor."""
    file_path = os.path.join(
        data_dir,
        f"{receptor}-{iter:04d}",
        data_file_name_patterns[sample_type].format(receptor=receptor, iter=iter),
    )
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Data file not found: {file_path}")
    return file_path


def parse_iteration(fname):
    """Extract iteration number from filename."""
    base = os.path.basename(fname)
    # e.g. 1IEP-0001.test.pdb.pdbqt.docked.inferred.csv
    iter_str = base.split("-")[1].split(".")[0]
    return int(iter_str)


IterData = Dict[SampleTypes, Any]
ReceptorData = Dict[int, IterData]
ReceptorStats = Dict[Stats, Any]


def load_data(data_dir: str, receptor: str, max_iteration_num: int) -> ReceptorData:
    """Load dataframes for each receptor and iteration."""

    res_data: ReceptorData = {}
    for iter in range(0, max_iteration_num):
        res_data[iter] = {}
        sample_type: SampleTypes
        for sample_type in SampleTypes:
            df_fn = find_data_files(data_dir, receptor, iter, sample_type)
            df = pd.read_csv(df_fn) if os.path.getsize(df_fn) > 0 else None
            res_data[iter][sample_type] = df

    return res_data


def compute_statistics(rec: str, data: ReceptorData) -> ReceptorStats:
    """Compute RMSE, R2, residuals, uncertainty distribution, train top affinity."""
    stats = {}
    iter_list: List[int] = sorted(data)
    (rmse, unc_box) = ([], [])

    train_top_affinity = []

    residuals_valid_before = {}
    residuals_valid = {}
    iter: int
    for iter in iter_list:
        df_test: pd.DataFrame = data[iter][SampleTypes.TEST]
        test_target = df_test["affinity"]
        test_pred = df_test["Pred"]
        rmse.append(np.sqrt(mean_squared_error(test_target, test_pred)))
        unc_box.append(df_test["Unc"].values)

        # mean affinity of top 1/10 train by prediction
        df_train = data[iter][SampleTypes.TRAIN]
        top_size: int = int(len(df_train) * 0.1)
        train_top_affinity.append(
            df_train.nsmallest(top_size, "affinity")["affinity"].mean()
        )

    stats = {
        Stats.ITERS: iter_list,
        Stats.RMSE: rmse,
        Stats.R2_TEST: compute_r2(iter_list, data, SampleTypes.TEST),
        Stats.R2_VALID: compute_r2(iter_list, data, SampleTypes.VALID),
        Stats.R2_TRAIN: compute_r2(iter_list, data, SampleTypes.TRAIN),
        Stats.RESIDUALS_TEST: compute_residuals(iter_list, data, SampleTypes.TEST),
        Stats.UNCERTAINTY: unc_box,
        Stats.TRAIN_TOP_AFFINITY: train_top_affinity,
        Stats.RESIDUALS_VALID_BEFORE: compute_residuals(
            iter_list, data, SampleTypes.VALID_BEFORE
        ),
        Stats.RESIDUALS_VALID: compute_residuals(iter_list, data, SampleTypes.VALID),
        Stats.RESIDUALS_TRAIN_BEFORE: compute_residuals(
            iter_list, data, SampleTypes.TRAIN_BEFORE
        ),
        Stats.RESIDUALS_TRAIN: compute_residuals(iter_list, data, SampleTypes.TRAIN),
    }
    return stats


def compute_r2(
    iter_list: List[int], data: ReceptorData, sample_type: SampleTypes
) -> List[float]:
    res_r2: List[float] = []
    iter: int
    for iter in iter_list:
        df: pd.DataFrame = data[iter][sample_type]
        data_target = pd.Series([], dtype=float)
        data_pred = pd.Series([], dtype=float)
        if df is not None:
            data_target = df["affinity"]
            data_pred = df["Pred"]
        res_r2.append(r2_score(data_target, data_pred))
    return res_r2


def compute_residuals(
    iter_list: List[int], data: ReceptorData, sample_type: SampleTypes
) -> Dict[int, Any]:
    res: Dict[int, Any] = {}
    iter: int
    for iter in iter_list:
        df: pd.DataFrame = data[iter][sample_type]
        data_target = pd.Series([], dtype=float)
        data_pred = pd.Series([], dtype=float)
        if df is not None:
            data_target = df["affinity"]
            data_pred = df["Pred"]
        res[iter] = (data_pred - data_target).values
    return res


def plot_all(receptor: str, data: ReceptorData, stats: ReceptorStats, out_dir):
    """Generate and save plots for each receptor."""
    os.makedirs(out_dir, exist_ok=True)

    iters: List[int] = stats[Stats.ITERS]
    # RMSE + residuals
    fig, ax1 = plt.subplots()
    ax1.plot(iters, stats[Stats.RMSE], color="tab:blue", marker="o", label="RMSE")
    ax1.set_xlabel("Iteration")
    ax1.set_ylabel("RMSE", color="tab:blue")
    ax1.tick_params(axis="y", labelcolor="tab:blue")
    ax2 = ax1.twinx()
    box_data = [stats[Stats.RESIDUALS_TEST][it] for it in iters]
    ax2.boxplot(
        box_data,
        positions=iters,
        widths=0.6,
        patch_artist=True,
        boxprops=dict(facecolor="tab:gray", alpha=0.3),
    )
    ax2.set_ylabel("Residuals", color="tab:gray")
    ax2.tick_params(axis="y", labelcolor="tab:gray")
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, f"fig01-{receptor}-rmse_residuals.png"))
    sys.stdout.write("Fig 1. RMSE residuals created\n")
    plt.close(fig)

    # R^2
    fig, ax = plt.subplots()
    ax.plot(iters, stats[Stats.R2_TEST], marker="o")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("R²")
    ax.set_title(f"{receptor} R² vs Iteration")
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, f"fig02-{receptor}-r2.png"))
    sys.stdout.write("Fig 2. R2 created\n")
    plt.close(fig)

    # Uncertainty
    fig, ax = plt.subplots()
    ax.boxplot(stats[Stats.UNCERTAINTY], positions=iters, widths=0.6)
    ax.set_xlabel("Iteration")
    ax.set_ylabel("Uncertainty")
    ax.set_title(f"{receptor} Uncertainty vs Iteration")
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, f"fig03-{receptor}-uncertainty.png"))
    sys.stdout.write(f"Fig 3. Uncertainty for {receptor} created\n")
    plt.close(fig)

    plot_train_top_affinity(receptor, iters, stats[Stats.TRAIN_TOP_AFFINITY], out_dir)
    plot_residuals(
        f"{receptor} Validation sample Residuals",
        iters,
        stats[Stats.RESIDUALS_VALID_BEFORE],
        stats[Stats.RESIDUALS_VALID],
        os.path.join(out_dir, f"fig05-{receptor}-validation_residuals.png"),
    )
    plot_residuals(
        f"{receptor} Training sample Residuals",
        iters,
        stats[Stats.RESIDUALS_TRAIN_BEFORE],
        stats[Stats.RESIDUALS_TRAIN],
        os.path.join(out_dir, f"fig06-{receptor}-training_residuals.png"),
    )
    plot_r2(
        f"{receptor} R² vs Iteration",
        iters,
        stats,
        os.path.join(out_dir, f"fig07-{receptor}-r2.png"),
    )
    for iter in iters[1:]:
        plot_sample(
            "Validation sample Before and After Training",
            iter,
            data,
            SampleTypes.VALID_BEFORE,
            SampleTypes.VALID,
            os.path.join(out_dir,f"fig10-{iter}-{receptor}-validation-sample.png"),
        )
        plot_sample(
            "Training sample Before and After Training",
            iter,
            data,
            SampleTypes.TRAIN_BEFORE,
            SampleTypes.TRAIN,
            os.path.join(out_dir, f"fig11-{iter}-{receptor}-training-sample.png"),
        )
        plot_sample(
            "Test sample Before and After Training",
            iter,
            data,
            SampleTypes.TEST_BEFORE,
            SampleTypes.TEST,
            os.path.join(out_dir, f"fig12-{iter}-{receptor}-testing-sample.png"),
        )


def plot_sample(
    title: str,
    iter: int,
    data: ReceptorData,
    before_sample_type,
    sample_type,
    out_fn: str,
):
    fig, ax = plt.subplots()
    # Compute R² scores for before and after samples
    
    r2_before = r2_score(data[iter][before_sample_type]["affinity"], data[iter][before_sample_type]["Pred"]) if len(data[iter][before_sample_type]["affinity"]) > 1 else float('nan')
    r2_after = r2_score(data[iter][sample_type]["affinity"], data[iter][sample_type]["Pred"]) if len(data[iter][sample_type]["affinity"]) > 1 else float('nan')
    before_data_target = data[iter][before_sample_type]["affinity"]
    before_data_pred = data[iter][before_sample_type]["Pred"]
    data_target = data[iter][sample_type]["affinity"]
    data_pred = data[iter][sample_type]["Pred"]
    # Scatter before and after training data
    ax.scatter(before_data_target, before_data_pred, marker="o", s=20, alpha=0.5, color="tab:blue", label=f"Before Data (R²={r2_before:.2f})")
    ax.scatter(data_target, data_pred, marker="o", s=20, alpha=0.5, color="tab:green", label=f"After Data (R²={r2_after:.2f})")
    # Plot regression lines
    if len(before_data_target) > 1:
        m0, b0 = np.polyfit(before_data_target, before_data_pred, 1)
        x0 = np.array([before_data_target.min(), before_data_target.max()])
        ax.plot(x0, m0*x0 + b0, color="tab:blue", linestyle="--")
    if len(data_target) > 1:
        m1, b1 = np.polyfit(data_target, data_pred, 1)
        x1 = np.array([data_target.min(), data_target.max()])
        ax.plot(x1, m1*x1 + b1, color="tab:green", linestyle="--")
    
    ax.set_xlabel("Target Affinity")
    ax.set_ylabel("Predicted Affinity")
    ax.set_title(title)
    ax.legend()
    ax.set_xlim(left=-15, right=0)
    ax.set_ylim(bottom=-15, top=0)
    ax.set_aspect("equal", adjustable="box")
    fig.tight_layout()
    fig.savefig(out_fn)
    sys.stdout.write(f"Figure '{os.path.basename(out_fn)}' created.\n")
    plt.close(fig)


def plot_r2(title: str, iters: List[int], stats, out_fn: str):
    fig, ax = plt.subplots()

    ax.plot(iters, stats[Stats.R2_TEST], marker="o", label="Test R²")
    ax.plot(iters, stats[Stats.R2_VALID], marker="o", label="Validation R²")
    ax.plot(iters, stats[Stats.R2_TRAIN], marker="o", label="Training R²")

    ax.set_xlabel("Iteration")
    ax.set_ylabel("R²")
    ax.set_title(title)
    ax.set_xticks(iters)
    ax.set_xticklabels([str(i) for i in iters])
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_fn)
    sys.stdout.write(f"Figure '{os.path.basename(out_fn)}' created.\n")
    plt.close(fig)


def plot_residuals(title, iters: List[int], residuals_before, residuals, out_fn: str):
    fig, ax1 = plt.subplots()
    # ax1.plot(iters, stats[Stats.RMSE], color="tab:blue", marker="o", label="RMSE")
    box_data_before = [residuals_before[it] for it in iters]
    box_data = [residuals[it] for it in iters]
    ax1.boxplot(
        box_data_before,
        positions=np.array(iters) - 0.15,
        widths=0.26,
        patch_artist=True,
        boxprops=dict(facecolor="tab:blue", alpha=0.7),
        label="Before Training",
    )
    ax1.boxplot(
        box_data,
        positions=np.array(iters) + 0.15,
        widths=0.26,
        patch_artist=True,
        boxprops=dict(facecolor="tab:green", alpha=0.7),
        label="After Training",
    )
    ax1.set_xlabel("Iteration")
    ax1.set_ylabel("Residuals")
    ax1.tick_params(axis="y")
    ax1.set_xticks(iters)
    ax1.set_xticklabels([str(i) for i in iters])
    ax1.set_title(title)
    ax1.legend()
    fig.tight_layout()
    fig.savefig(out_fn)
    sys.stdout.write(f"Figure '{os.path.basename(out_fn)}' created.\n")
    plt.close(fig)


def plot_train_top_affinity(receptor: str, iters, train_top_affinity, out_dir: str):
    """Generate and save plot for top-100 affinity."""
    fig, ax = plt.subplots()
    ax.plot(iters, train_top_affinity, marker="o")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("Mean Affinity Top-100")
    ax.set_title(f"{receptor} Top-100 Affinity vs Iteration")

    # Set integer ticks and labels for x-axis
    ax.set_xticks(iters)
    ax.set_xticklabels([str(i) for i in iters])
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))

    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, f"fig04-{receptor}-train_top_affinity.png"))
    sys.stdout.write(f"Fig 4. Train top affinity for {receptor} created\n")
    plt.close(fig)


def parse_args() -> Options:
    # fmt: off
    parser = argparse.ArgumentParser(
        description="Plot AL docking metrics per receptor."
    )
    parser.add_argument(
        "--data-dir", dest="data_dir", type=str, required=True,
        help="Directory containing inferred CSV results")
    parser.add_argument(
        "--receptor", type=str, required=True,
        help="Receptor IDs (e.g. 1IEP 1YOM)")
    parser.add_argument(
        "--max-iteration-num", dest="max_iteration_num", type=int,
        help="Maximum number of iterations to process")
    parser.add_argument(
        "--out-dir", dest="out_dir",type=str, required=True,
        help="Directory to save output figures")
    # fmt: on
    return Options(**vars(parser.parse_args()))


def main(opts: Options):
    data: ReceptorData = load_data(opts.data_dir, opts.receptor, opts.max_iteration_num)
    stats = compute_statistics(opts.receptor, data)
    plots = plot_all(opts.receptor, data, stats, opts.out_dir)


if __name__ == "__main__":
    print("Arguments")
    opts = parse_args()
    for k, v in vars(opts).items():
        print(f"{k}: {v}")
    main(opts)
