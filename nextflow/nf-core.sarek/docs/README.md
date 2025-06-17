## Introduction

**sarek** is a workflow designed to detect variants on whole genome or targeted sequencing data. Initially designed for Human, and Mouse, it can work on any species with a reference genome. Sarek can also handle tumour / normal pairs and could include additional relapses.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/sarek/results).

## Pipeline summary

Depending on the options and samples provided, the pipeline can currently perform the following:

- Form consensus reads from UMI sequences (`fgbio`)
- Sequencing quality control and trimming (`FastQC`, `fastp`)
- Map Reads to Reference (`BWA-mem` or `BWA-mem2` or `dragmap`)
- Process BAM file (`GATK MarkDuplicates`, `GATK BaseRecalibrator`, `GATK ApplyBQSR`)
- Summarise alignment statistics (`samtools stats`, `mosdepth`)
- Variant calling (enabled by `--tools`, see [compatibility](https://github.com/nf-core/sarek/blob/master/docs/usage.md#which-variant-calling-tool-is-implemented-for-which-data-type)):
  - `HaplotypeCaller`
  - `freebayes`
  - `mpileup`
  - `Strelka2`
  - `DeepVariant`
  - `Mutect2`
  - `Manta`
  - `TIDDIT`
  - `ASCAT`
  - `Control-FREEC`
  - `CNVkit`
  - `MSIsensor-pro`
- Variant filtering and annotation (`SnpEff`, `Ensembl VEP`)
- Summarise and represent QC (`MultiQC`)

## Usage

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
patient,sample,lane,fastq_1,fastq_2
ID1,S1,L002,ID1_S1_L002_R1_001.fastq.gz,ID1_S1_L002_R2_001.fastq.gz
```

Each row represents a pair of fastq files (paired end).

## Pipeline output

To see the the results of a test run with a full size dataset refer to the [results](https://nf-co.re/sarek/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/sarek/output).

## Parameters

- `samplesheet_path` - Defines a path to the sheet of samples
- `custom_config_path` - Defines a path to the custom config for the pipeline including paths to the reference genome fasta and reference annotation.
- `output_storage` - Path to a storage in which to place the processing results.

## Example

`custom_config_path` file example:
```
params {
  fasta = 's3://epm-syngenta-demo/Genomes/Arabidopsis_thaliana/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa'
  gtf = 's3://epm-syngenta-demo/Genomes/Arabidopsis_thaliana/Arabidopsis_thaliana.TAIR10.59.gtf.gz'
  
  // default params
  split_fastq       = 0         // no FASTQ splitting
  tools             = 'strelka,mutect2,freebayes,ascat,manta,cnvkit,controlfreec,vep'
  download_cache    = true

  // Ignore params that will throw warning through params validation
  schema_ignore_params = 'genomes,snpeff_version,vep_version'
}
process {
  clusterOptions = {
    def memory_per_slot = task.memory.toGiga() / task.cpus.toInteger()
    memory_per_slot = memory_per_slot > 0 ? memory_per_slot : 1
    def memory_resource = "$CP_CAP_GE_CONSUMABLE_RESOURCE_NAME_RAM"
    memory_resource = memory_resource != "[:]" ? memory_resource : "ram"
  }
}
```