#!/usr/bin/env python3

from dataclasses import dataclass
import os
import sys
import time
import argparse

from functools import partial
from typing import cast, List, Tuple, Union

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from torch import Tensor
from dgl.heterograph import DGLHeteroGraph

script_dir = os.path.dirname(os.path.abspath(os.path.realpath(__file__)))
if script_dir not in sys.path:
    sys.path.append(script_dir)

from libs.io_utils import get_dataset
from libs.io_utils import MyDataset
from libs.io_utils import smi_collate_fn

from libs.models import MyModel

from libs.utils import str2bool
from libs.utils import set_seed
from libs.utils import set_device
from libs.utils import evaluate_regression
from libs.utils import heteroscedastic_loss


@dataclass(frozen=True)
class Options:
    title: str
    seed: int

    train_fp: str
    test_fp: str
    valid_fp: Union[str, None]

    smiles_col: str
    target_col: str

    # method: str
    use_gpu: bool
    model_type: str
    num_layers: int
    hidden_dim: int
    out_dim: int
    readout: str
    multiply_num_pma: bool
    dropout_prob: float
    optimizer: str
    num_epoches: int
    num_workers: int
    batch_size: int
    lr: float
    weight_decay: float

    input: Union[str, None]
    save_model: bool
    output: str


def get_dataset2(
    opts: Options,
) -> Tuple[pd.DataFrame, pd.DataFrame, Union[pd.DataFrame, None]]:
    train_set = pd.read_csv(opts.train_fp)
    test_set = pd.read_csv(opts.test_fp)
    valid_set = pd.read_csv(opts.valid_fp) if opts.valid_fp else None
    return train_set, test_set, valid_set


def register_shape_hooks(model):
    hooks = []

    def hook_fn(module, input, output):
        class_name = module.__class__.__name__
        # for i, input in enumerate(input):
        #     print(f"{class_name:<30} > input {i} shape: {getattr(input, 'shape', 'non-tensor')}")
        # print(f"{class_name:<30} < output shape: {getattr(output, 'shape', 'non-tensor')}\n")

    for module in model.modules():
        if isinstance(module, (torch.nn.Linear, torch.nn.Conv2d, torch.nn.LayerNorm)):
            # hooks.append(module.register_forward_pre_hook(pre_hook_fn))
            hooks.append(module.register_forward_hook(hook_fn))
    return hooks


def main(args: Options):
    # Set random seeds and device
    set_seed(seed=1234)
    device = set_device(args.use_gpu)
    # Prepare datasets and dataloaders
    train_set, test_set, valid_set = get_dataset2(args)

    train_ds, test_ds, valid_ds = (
        MyDataset(s, args.smiles_col, args.target_col) if s is not None else None
        for s in (train_set, test_set, valid_set)
    )

    collate_fn = partial(
        smi_collate_fn,
    )

    train_loader = DataLoader(
        dataset=cast(MyDataset, train_ds),
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        collate_fn=collate_fn,
    )

    valid_loader = (
        DataLoader(
            dataset=valid_ds,
            batch_size=args.batch_size,
            shuffle=False,
            num_workers=args.num_workers,
            collate_fn=collate_fn,
        )
        if valid_ds
        else None
    )

    test_loader = DataLoader(
        dataset=cast(MyDataset, test_ds),
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
        collate_fn=collate_fn,
    )

    # Construct model and load trained parameters if it is possible
    model = MyModel(
        model_type=args.model_type,
        num_layers=args.num_layers,
        hidden_dim=args.hidden_dim,
        readout=args.readout,
        dropout_prob=args.dropout_prob,
        out_dim=args.out_dim,
        multiply_num_pma=args.multiply_num_pma,
    )
    if args.input:
        ckpt = torch.load(args.input, map_location=device)
        model.load_state_dict(ckpt["model_state_dict"])

    model = model.to(device)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=args.lr,
        weight_decay=args.weight_decay,
    )

    scheduler = torch.optim.lr_scheduler.StepLR(
        optimizer=optimizer,
        step_size=40,
        gamma=0.1,
    )
    loss_fn = partial(heteroscedastic_loss)
    # '''
    epoch: int = 0
    for epoch in range(args.num_epoches):
        hooks = register_shape_hooks(model)
        # Train
        model.train()
        num_batches = len(train_loader)
        train_loss = 0
        y_list = []
        pred_list = []
        for i, batch in enumerate(train_loader):
            st = time.time()
            optimizer.zero_grad()

            graph, y = batch[0], batch[1]
            graph = graph.to(device)
            y = y.to(device)
            y = y.float()
            feat: Tensor = cast(
                Tensor, graph.ndata["h"]
            )  # batch molecules atoms / vertexes
            feat = feat.to(device)
            pred, alpha = model(graph, feat, training=True)
            y_list.append(y)
            pred_list.append(pred[:, 0])

            loss = loss_fn(pred, y)
            loss.backward()
            optimizer.step()

            train_loss += loss.detach().cpu().numpy()

            et = time.time()
            report_epoch(
                "Train", epoch, i, num_batches, loss.detach().cpu().numpy(), st, et
            )
        scheduler.step()
        train_loss /= num_batches
        train_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)
        for h in hooks:
            h.remove()

        model.eval()
        with torch.no_grad():
            valid_metrics = (0, 0, 0)
            if valid_loader is not None:
                # Validation
                valid_loss: float = 0
                num_batches: int = len(valid_loader)
                y_list: List[Tensor] = []
                pred_list: List[Tensor] = []
                for i, batch in enumerate(valid_loader):
                    st = time.time()

                    y: Tensor = cast(Tensor, None)
                    tmp_list: List[Tensor] = []
                    for _ in range(3):
                        graph: DGLHeteroGraph
                        graph, y = batch[0].clone(), batch[1].clone()
                        graph = graph.to(device)
                        y = y.to(device)
                        y = y.float()

                        feat: Tensor = cast(Tensor, graph.ndata["h"])
                        feat = feat.to(device)
                        pred, alpha = model(graph, feat, training=True)
                        pred = pred.unsqueeze(-1)
                        tmp_list.append(pred)

                    tmp_t: Tensor = torch.cat(tmp_list, dim=-1)
                    tmp_m: Tensor = torch.mean(tmp_t, dim=-1)

                    y_list.append(y)
                    pred_list.append(tmp_m[:, 0])

                    loss = loss_fn(tmp_m, y)
                    valid_loss += loss.detach().cpu().numpy()

                    et = time.time()
                    report_epoch(
                        "Valid",
                        epoch,
                        i,
                        num_batches,
                        loss.detach().cpu().numpy(),
                        st,
                        et,
                    )
                valid_loss /= num_batches
                valid_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)

            # Test
            test_loss = 0
            num_batches = len(test_loader)
            y_list = []
            pred_list = []
            for i, batch in enumerate(test_loader):
                st = time.time()

                y: Tensor = cast(Tensor, None)
                tmp_list: List[Tensor] = []
                for _ in range(3):
                    graph, y = batch[0].clone(), batch[1].clone()
                    graph = graph.to(device)
                    y = y.to(device)
                    y = y.float()

                    pred, alpha = model(graph, training=True)
                    pred = pred.unsqueeze(-1)
                    tmp_list.append(pred)

                tmp_t: Tensor = torch.cat(tmp_list, dim=-1)
                tmp_m: Tensor = torch.mean(tmp_t, dim=-1)

                y_list.append(y)
                pred_list.append(tmp_m[:, 0])

                loss = loss_fn(tmp_m, y)
                test_loss += loss.detach().cpu().numpy()

                et = time.time()
                report_epoch(
                    "Test", epoch, i, num_batches, loss.detach().cpu().numpy(), st, et
                )
            test_loss /= num_batches
            test_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)
        print(
            f"End of {epoch + 1:3d}-th epoch | "
            f" MSE: {train_metrics[0]:7.3f} | {valid_metrics[0]:7.3f} | {test_metrics[0]:7.3f}; "
            f"RMSE: {train_metrics[1]:7.3f} | {valid_metrics[1]:7.3f} | {test_metrics[1]:7.3f}; "
            f"  R2: {train_metrics[2]:7.3f} | {valid_metrics[2]:7.3f} | {test_metrics[2]:7.3f}."
        )

    # '''

    if opts.save_model and opts.output is not None:
        torch.save(
            {
                "epoch": epoch,
                "model_state_dict": model.state_dict(),
                "optimizer_state_dict": optimizer.state_dict(),
            },
            opts.output,
        )
    # '''

    # ckpt = torch.load(save_path, map_location=device)
    # model.load_state_dict(ckpt["model_state_dict"])

    # print(f"Final validation")
    # model.eval()
    # with torch.no_grad():
    #     # Train set
    #     train_loss = 0
    #     num_batches = len(train_loader)
    #     y_list = []
    #     pred_list = []
    #     for i, batch in enumerate(train_loader):
    #         graph, y = batch[0], batch[1]
    #         graph = graph.to(device)
    #         y = y.to(device)
    #         y = y.float()
    #         feat = graph.ndata["h"]
    #         feat = feat.to(device)
    #         pred, alpha = model(graph, feat, training=False)
    #         y_list.append(y)
    #         pred_list.append(pred[:, 0])

    #         loss = loss_fn(pred, y)
    #         train_loss += loss.detach().cpu().numpy()
    #     train_loss /= num_batches
    #     train_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)

    #     # Validation
    #     valid_loss = 0
    #     num_batches = len(valid_loader)
    #     y_list = []
    #     pred_list = []
    #     for i, batch in enumerate(valid_loader):
    #         graph, y = batch[0], batch[1]
    #         graph = graph.to(device)
    #         y = y.to(device)
    #         y = y.float()
    #         feat = graph.ndata["h"]
    #         feat = feat.to(device)
    #         pred, alpha = model(graph, feat, training=False)
    #         y_list.append(y)
    #         pred_list.append(pred[:, 0])

    #         loss = loss_fn(pred, y)
    #         valid_loss += loss.detach().cpu().numpy()
    #     valid_loss /= num_batches
    #     valid_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)

    #     # Test
    #     test_loss = 0
    #     num_batches = len(test_loader)
    #     y_list = []
    #     pred_list = []
    #     for i, batch in enumerate(test_loader):
    #         graph, y = batch[0], batch[1]
    #         graph = graph.to(device)
    #         y = y.to(device)
    #         y = y.float()
    #         feat = graph.ndata["h"]
    #         feat = feat.to(device)
    #         pred, alpha = model(graph, feat, training=False)
    #         y_list.append(y)
    #         pred_list.append(pred[:, 0])

    #         loss = loss_fn(pred, y)
    #         test_loss += loss.detach().cpu().numpy()
    #     test_loss /= num_batches
    #     test_metrics = evaluate_regression(y_list=y_list, pred_list=pred_list)
    #     print(
    #         f"Final evaluation!!!"
    #         f" MSE: {train_metrics[0]:.3f} | {valid_metrics[0]:.3f} | {test_metrics[0]:.3f};"
    #         f" RMSE: {train_metrics[1]:.3f} | {valid_metrics[1]:.3f} | {test_metrics[1]:.3f};"
    #         f" R2: {train_metrics[2]:.3f} | {valid_metrics[2]:.3f} | {test_metrics[2]:.3f}"
    #     )


def report_epoch(type, epoch, batch, num_batches, loss, st, et):
    print(
        f"{type:6} !!!  Epoch: {(epoch + 1):>3d} "
        f"Batch: {batch + 1:>{len(str(num_batches))}} / {num_batches} "
        f"Loss: {loss:>7.3f} "
        f"Time spent: {(et - st):>7.3f} (s)"
    )


def is_valid_file(parser, fp):
    if not os.path.exists(fp):
        parser.error(f"The file {fp} does not exist!")
    return fp


def parse_args() -> Options:
    # fmt:off
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--title", type=str, required=True, 
        help="Job title of this execution")
    parser.add_argument(
        "--seed", type=int, required=True, 
        help="Seed used for dataset splitting")

    parser.add_argument(
        "--train", dest="train_fp", type=lambda x: is_valid_file(parser, x), required=True,
        help="Path to training dataset")
    parser.add_argument(
        "--test", dest="test_fp", type=lambda x: is_valid_file(parser, x), required=True,
        help="Path to test dataset")
    parser.add_argument(
        "--valid", dest="valid_fp", type=lambda x: is_valid_file(parser, x), required=False,
        help="Path to validation dataset")

    parser.add_argument(
        "--target_col", type=str, required=True,
        help="Datasets target value column name")
    parser.add_argument(
        "--smiles_col", type=str, default="SMILES",
        help="Datasets SMILES value column name")

    parser.add_argument(
        "--use_gpu", type=str2bool, default=True, 
        help="whether to use GPU device")
    parser.add_argument(
        "--model_type", type=str, default="gine",
        help="Type of GNN model, Options: gcn, gin, gine, gat")
    parser.add_argument(
        "--num_layers", type=int, default=4,
        help="Number of GIN layers for ligand featurization")
    parser.add_argument(
        "--hidden_dim", type=int, default=128, 
        help="Dimension of hidden features")
    parser.add_argument(
        "--out_dim", type=int, default=2, 
        help="Dimension of final outputs")
    parser.add_argument(
        "--readout", type=str, default="pma",
        help="Readout method, Options: sum, mean, ...")
    parser.add_argument(
        "--multiply_num_pma", type=str2bool, default=False,
        help="whether to multiply number of atoms in the PMA layer")
    parser.add_argument(
        "--dropout_prob", type=float, default=0.2,
        help="Probability of dropout on node features")

    parser.add_argument(
        "--optimizer", type=str, default="adam", 
        help="Options: adam, sgd, ...")
    parser.add_argument(
        "--num_epoches", type=int, default=150, 
        help="Number of training epoches")
    parser.add_argument(
        "--num_workers", type=int, default=6,
        help="Number of workers to run dataloaders")
    parser.add_argument(
        "--batch_size", type=int, default=250,
        help="Number of samples in a single batch")
    parser.add_argument(
        "--lr", type=float, default=1e-3, 
        help="Initial learning rate")
    parser.add_argument(
        "--weight_decay", type=float, default=1e-6, 
        help="Weight decay coefficient")

    parser.add_argument(
        "--input", type=str, required=False,
        help="Input model .pth file name (if exists)")
    parser.add_argument(
        "--save_model", type=str2bool, default=True, 
        help="whether to save model")
    parser.add_argument(
        "--output", type=str, required=False,
        help="Output model .pth file name",
    )
    # fmt: on
    return Options(**vars(parser.parse_args()))


if __name__ == "__main__":
    print(f"Arguments")
    opts = parse_args()
    for k, v in vars(opts).items():
        print(f"{k}: {v}")

    main(opts)
