#!/usr/bin/env python3

"""
Pre:
    Use argparse to parse arguments.
    Use csv to read .csv files.
    Use dataclass frozen to store command line options.
    Use class types for `Pipeline` and `DatastorageRule`.
    Typing for function arguments and output value is mandatory.

The purpose of the script:
    To generate datastorage_rule.json files for pipelines based on data from CSV files.

Operation algorithm:
    1. read pipeline data from pipeline.csv file (columns: pipeline_id, name)
    2. read rules from datastorage_rule.csv file (columns: pipeline_id, file_mask, move_to_sts, is_result, name)
    3. in the output folder create folders corresponding to the names of the pipelines
    4. in each folder create a datastorage_rule.json file
    5. in the datastorage_rule.json file for each pipeline create a structure with a list of rules for this pipeline:
    ```
    {
        "datastorage_rule": [
            {
                "file_mask": "<file_mask_value>",
                "move_to_sts": true|false,
                "is_result": true|false,
                "name: "<rule_name>"
            },
            ...
        ]
    }
    ```
    6. Output report with indented list of pipelines and rules for each pipeline.
"""

import argparse
import csv
import json
import os
import sys
from dataclasses import dataclass
from typing import List, Dict, Any


@dataclass(frozen=True)
class Options:
    pipeline_csv: str
    datastorage_rule_csv: str
    output_dir: str


@dataclass
class DatastorageRule:
    file_mask: str
    move_to_sts: bool
    is_result: bool
    name: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "file_mask": self.file_mask,
            "move_to_sts": self.move_to_sts,
            "is_result": self.is_result,
            "name": self.name
        }


@dataclass
class Pipeline:
    id: int
    name: str
    rules: List[DatastorageRule]


def read_pipelines(pipeline_csv: str) -> Dict[int, Pipeline]:
    pipelines = {}
    with open(pipeline_csv, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            pipeline_id = int(row['pipeline_id'])
            pipelines[pipeline_id] = Pipeline(
                id=pipeline_id,
                name=row['pipeline_name'],
                rules=[]
            )
    return pipelines


def read_rules(datastorage_rule_csv: str, pipelines: Dict[int, Pipeline]) -> List[Pipeline]:
    with open(datastorage_rule_csv, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            pipeline_id = int(row['pipeline_id'])
            if pipeline_id in pipelines:
                rule = DatastorageRule(
                    file_mask=row['file_mask'],
                    move_to_sts=row['move_to_sts'].lower() == 'true',
                    is_result=row['is_result'].lower() == 'true',
                    name=row['name']
                )
                pipelines[pipeline_id].rules.append(rule)

    return list(pipelines.values())


def generate_datastorage_rules(pipelines: List[Pipeline], output_dir: str) -> None:
    for pipeline in pipelines:
        # Create pipeline directory
        pipeline_dir = os.path.join(output_dir, pipeline.name)
        os.makedirs(pipeline_dir, exist_ok=True)

        # Generate datastorage_rule.json
        rules_file = os.path.join(pipeline_dir, "datastorage_rule.json")
        rules_data = {"datastorage_rule": [rule.to_dict() for rule in pipeline.rules]}

        with open(rules_file, "w") as f:
            json.dump(rules_data, f, indent=4)


def print_report(pipelines: List[Pipeline]) -> None:
    print("\nGenerated datastorage rules for the following pipelines:")
    for pipeline in pipelines:
        print(f"\n{pipeline.name}:")
        for rule in pipeline.rules:
            print(f"  - {rule.name} (mask: {rule.file_mask})")
            print(f"    move_to_sts: {rule.move_to_sts}, is_result: {rule.is_result}")


def main(opts: Options) -> None:
    try:
        # Create output directory if it doesn't exist
        os.makedirs(opts.output_dir, exist_ok=True)

        # Read data from CSV files
        pipelines = read_pipelines(opts.pipeline_csv)
        pipelines_list = read_rules(opts.datastorage_rule_csv, pipelines)

        # Generate datastorage rule files
        generate_datastorage_rules(pipelines_list, opts.output_dir)

        # Print report
        print_report(pipelines_list)

    except Exception as ex:
        print(f"Error: {ex}", file=sys.stderr)
        sys.exit(1)


def parse_args() -> Options:
    parser = argparse.ArgumentParser(
        description="Generate datastorage_rule.json files for pipelines"
    )
    parser.add_argument("--pipeline-csv", required=True, help="Path to pipeline.csv file")
    parser.add_argument("--datastorage-rule-csv", required=True, help="Path to datastorage_rule.csv file")
    parser.add_argument(
        "--output-dir", required=True, help="Output directory for generated files"
    )

    return Options(**vars(parser.parse_args()))


if __name__ == "__main__":
    opts = parse_args()
    main(opts)
