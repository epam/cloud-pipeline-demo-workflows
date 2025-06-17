## Introduction

**methylseq** is a bioinformatics analysis pipeline used for Methylation (Bisulfite) sequencing data. It pre-processes raw data from FastQ inputs, aligns the reads and performs extensive quality-control on the results.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker / Singularity containers making installation trivial and results highly reproducible.

The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/methylseq/results).

> Read more about **Bisulfite Sequencing & Three-Base Aligners** used in this pipeline [here](https://github.com/nf-core/methylseq/blob/master/docs/bs-seq-primer.md)

## Pipeline Summary

The pipeline allows you to choose between running either [Bismark](https://github.com/FelixKrueger/Bismark) or [bwa-meth](https://github.com/brentp/bwa-meth) / [MethylDackel](https://github.com/dpryan79/methyldackel).

Choose between workflows by using `--aligner bismark` (default, uses bowtie2 for alignment), `--aligner bismark_hisat` or `--aligner bwameth`. For higher performance, the pipeline can leverage the [Parabricks implementation of bwa-meth (fq2bammeth)](https://docs.nvidia.com/clara/parabricks/latest/documentation/tooldocs/man_fq2bam_meth.html), which implements the baseline tool `bwa-meth` in a performant method using fq2bam (BWA-MEM + GATK) as a backend for processing on GPU. To use this option, include the `--use_gpu` flag along with `--aligner bwameth`.

| Step                                         | Bismark workflow         | bwa-meth workflow     |
| -------------------------------------------- | ------------------------ | --------------------- |
| Generate Reference Genome Index _(optional)_ | Bismark                  | bwa-meth              |
| Merge re-sequenced FastQ files               | cat                      | cat                   |
| Raw data QC                                  | FastQC                   | FastQC                |
| Adapter sequence trimming                    | Trim Galore!             | Trim Galore!          |
| Align Reads                                  | Bismark (bowtie2/hisat2) | bwa-meth              |
| Deduplicate Alignments                       | Bismark                  | Picard MarkDuplicates |
| Extract methylation calls                    | Bismark                  | MethylDackel          |
| Sample report                                | Bismark                  | -                     |
| Summary Report                               | Bismark                  | -                     |
| Alignment QC                                 | Qualimap _(optional)_    | Qualimap _(optional)_ |
| Sample complexity                            | Preseq _(optional)_      | Preseq _(optional)_   |
| Project Report                               | MultiQC                  | MultiQC               |

## Usage

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2,genome
SRR389222_sub1,https://github.com/nf-core/test-datasets/raw/methylseq/testdata/SRR389222_sub1.fastq.gz,,
SRR389222_sub2,https://github.com/nf-core/test-datasets/raw/methylseq/testdata/SRR389222_sub2.fastq.gz,,
SRR389222_sub3,https://github.com/nf-core/test-datasets/raw/methylseq/testdata/SRR389222_sub3.fastq.gz,,
Ecoli_10K_methylated,https://github.com/nf-core/test-datasets/raw/methylseq/testdata/Ecoli_10K_methylated_R1.fastq.gz,https://github.com/nf-core/test-datasets/raw/methylseq/testdata/Ecoli_10K_methylated_R2.fastq.gz,
```

> Each row represents a fastq file (single-end) or a pair of fastq files (paired end).

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/methylseq/usage) and the [parameter documentation](https://nf-co.re/methylseq/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/methylseq/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the [output documentation](https://nf-co.re/methylseq/output).

## Parameters

- `samplesheet_path`  - Defines a path to the sheet of input samples
- `output_storage`  - Path to a storage in which to place the processing results.
- `custom_config_path`  - Defines a path to the custom config for the pipeline including paths to the reference genome fasta and reference annotation.
- `params_file` - Defines a path to the pipeline params JSON/YAML file

## Example

`custom_config_path`  file example:

```
params {
	fasta = "gs://nf-core-demo-data/test-configs/methylseq-test/reference/genome.fa.gz"
	fasta_index = "gs://nf-core-demo-data/test-configs/methylseq-test/reference/genome.fa.fai"
}

process {
	clusterOptions = {
		def memory_per_slot = task.memory.toGiga() / task.cpus.toInteger()
		memory_per_slot = memory_per_slot > 0 ? memory_per_slot : 1
		def memory_resource = "$CP_CAP_GE_CONSUMABLE_RESOURCE_NAME_RAM"
		memory_resource = memory_resource != "[:]" ? memory_resource : "ram"
		"-l $memory_resource=${memory_per_slot}G"
	}
}
```

## Credits

nf-core/methylseq was originally written by Phil Ewels ([@ewels](https://github.com/ewels)), and Sateesh Peri ([@sateeshperi](https://github.com/sateeshperi)) is its active maintainer.

We thank the following people for their extensive assistance in the development of this pipeline:

- Felix Krueger ([@FelixKrueger](https://github.com/FelixKrueger))
- Edmund Miller ([@EMiller88](https://github.com/emiller88))
- Rickard Hammarén ([@Hammarn](https://github.com/Hammarn/))
- Alexander Peltzer ([@apeltzer](https://github.com/apeltzer/))
- Patrick Hüther ([@phue](https://github.com/phue/))
- Maxime U Garcia ([@maxulysse](https://github.com/maxulysse/))

