## Introduction

**nf-rnaseq** is a bioinformatics pipeline that can be used to analyse RNA sequencing data obtained from organisms with a reference genome and annotation.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

On release, automated continuous integration tests run the pipeline on a [full-sized dataset](https://github.com/nf-core/test-datasets/tree/rnaseq#full-test-dataset-origin) obtained from the ENCODE Project Consortium on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/rnaseq/results).

## Pipeline summary

1. Merge re-sequenced FastQ files ([`cat`](http://www.linfo.org/cat.html))
2. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
3. UMI extraction ([`UMI-tools`](https://github.com/CGATOxford/UMI-tools))
4. Adapter and quality trimming ([`Trim Galore!`](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/))
5. Removal of genome contaminants ([`BBSplit`](http://seqanswers.com/forums/showthread.php?t=41288))
6. Removal of ribosomal RNA ([`SortMeRNA`](https://github.com/biocore/sortmerna))
7. Choice of multiple alignment and quantification routes:
    1. [`STAR`](https://github.com/alexdobin/STAR) -> [`Salmon`](https://combine-lab.github.io/salmon/)
    2. [`STAR`](https://github.com/alexdobin/STAR) -> [`RSEM`](https://github.com/deweylab/RSEM)
    3. [`HiSAT2`](https://ccb.jhu.edu/software/hisat2/index.shtml) -> **NO QUANTIFICATION**
8. Sort and index alignments ([`SAMtools`](https://sourceforge.net/projects/samtools/files/samtools/))
9. UMI-based deduplication ([`UMI-tools`](https://github.com/CGATOxford/UMI-tools))
10. Duplicate read marking ([`picard MarkDuplicates`](https://broadinstitute.github.io/picard/))
11. Transcript assembly and quantification ([`StringTie`](https://ccb.jhu.edu/software/stringtie/))
12. Create bigWig coverage files ([`BEDTools`](https://github.com/arq5x/bedtools2/), [`bedGraphToBigWig`](http://hgdownload.soe.ucsc.edu/admin/exe/))
13. Extensive quality control:
    1. [`RSeQC`](http://rseqc.sourceforge.net/)
    2. [`Qualimap`](http://qualimap.bioinfo.cipf.es/)
    3. [`dupRadar`](https://bioconductor.org/packages/release/bioc/html/dupRadar.html)
    4. [`Preseq`](http://smithlabresearch.org/software/preseq/)
    5. [`DESeq2`](https://bioconductor.org/packages/release/bioc/html/DESeq2.html)
14. Pseudo-alignment and quantification ([`Salmon`](https://combine-lab.github.io/salmon/); *optional*)
15. Present QC for raw read, alignment, gene biotype, sample similarity, and strand-specificity checks ([`MultiQC`](http://multiqc.info/), [`R`](https://www.r-project.org/))

> **NB:** Quantification isn't performed if using `--aligner hisat2` due to the lack of an appropriate option to calculate accurate expression estimates from HISAT2 derived genomic alignments. However, you can use this route if you have a preference for the alignment, QC and other types of downstream analysis compatible with the output of HISAT2.
> **NB2:** By default, this pipeline uses DESeq2 rlog() function, which will run forever if 50+ samples are processed. It shall be switched to vst() function instead. This can be done by adding `--vst TRUE` into a configuration file (see `Example` section).

## Parameters

- `samplesheet_path` - Defines a path to the sheet of samples
- `custom_config_path` - Defines a path to the custom config for the pipeline including paths to the reference genome fasta and reference annotation.
- `output_storage` - Path to a storage in which to place the processing results. `${RUN_ID}` placeholder is available.

## Config example

`custom_config_path` file example:
```
params {
  fasta = 's3://epm-syngenta-demo/Genomes/Arabidopsis_thaliana/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa'
  gtf = 's3://epm-syngenta-demo/Genomes/Arabidopsis_thaliana/Arabidopsis_thaliana.TAIR10.59.gtf.gz'
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

withName: DESEQ2_QC_SALMON {
     ext.args = "--vst TRUE"
}
```

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

**samplesheet.csv**:

```csv
sample,fastq_1,fastq_2,strandedness
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,auto
CONTROL_REP1,AEG588A1_S1_L003_R1_001.fastq.gz,AEG588A1_S1_L003_R2_001.fastq.gz,auto
CONTROL_REP1,AEG588A1_S1_L004_R1_001.fastq.gz,AEG588A1_S1_L004_R2_001.fastq.gz,auto
```

Each row represents a fastq file (single-end) or a pair of fastq files (paired end). Rows with the same sample identifier are considered technical replicates and merged automatically. The strandedness refers to the library preparation and will be automatically inferred if set to `auto`.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

Now, you can run the pipeline using:

```bash
nextflow run nf-core/rnaseq \
    --input <SAMPLESHEET> \
    --outdir <OUTDIR> \
    --gtf <GTF> \
    --fasta <GENOME FASTA> \
    -profile <docker/singularity/.../institute>
```

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/rnaseq/usage) and the [parameter documentation](https://nf-co.re/rnaseq/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/rnaseq/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/rnaseq/output).

This pipeline quantifies RNA-sequenced reads relative to genes/transcripts in the genome and normalizes the resulting data. It does not compare the samples statistically in order to assign significance in the form of FDR or P-values. For downstream analyses, the output files from this pipeline can be analysed directly in statistical environments like [R](https://www.r-project.org/), [Julia](https://julialang.org/) or via the [nf-core/differentialabundance](https://github.com/nf-core/differentialabundance/) pipeline.

## Online videos

A short talk about the history, current status and functionality on offer in this pipeline was given by Harshil Patel ([@drpatelh](https://github.com/drpatelh)) on [8th February 2022](https://nf-co.re/events/2022/bytesize-32-nf-core-rnaseq) as part of the nf-core/bytesize series.

You can find numerous talks on the [nf-core events page](https://nf-co.re/events) from various topics including writing pipelines/modules in Nextflow DSL2, using nf-core tooling, running nf-core pipelines as well as more generic content like contributing to Github. Please check them out!

## Credits

These scripts were originally written for use at the [National Genomics Infrastructure](https://ngisweden.scilifelab.se), part of [SciLifeLab](http://www.scilifelab.se/) in Stockholm, Sweden, by Phil Ewels ([@ewels](https://github.com/ewels)) and Rickard Hammarén ([@Hammarn](https://github.com/Hammarn)).

The pipeline was re-written in Nextflow DSL2 and is primarily maintained by Harshil Patel ([@drpatelh](https://github.com/drpatelh)) from [Seqera Labs, Spain](https://seqera.io/).

The pipeline workflow diagram was initially designed by Sarah Guinchard ([@G-Sarah](https://github.com/G-Sarah)) and James Fellows Yates ([@jfy133](https://github.com/jfy133)), further modifications where made by Harshil Patel ([@drpatelh](https://github.com/drpatelh)) and Maxime Garcia ([@maxulysse](https://github.com/maxulysse)).

Many thanks to other who have helped out along the way too, including (but not limited to):

- [Alex Peltzer](https://github.com/apeltzer)
- [Colin Davenport](https://github.com/colindaven)
- [Denis Moreno](https://github.com/Galithil)
- [Edmund Miller](https://github.com/edmundmiller)
- [Gregor Sturm](https://github.com/grst)
- [Jacki Buros Novik](https://github.com/jburos)
- [Lorena Pantano](https://github.com/lpantano)
- [Matthias Zepper](https://github.com/MatthiasZepper)
- [Maxime Garcia](https://github.com/maxulysse)
- [Olga Botvinnik](https://github.com/olgabot)
- [@orzechoj](https://github.com/orzechoj)
- [Paolo Di Tommaso](https://github.com/pditommaso)
- [Rob Syme](https://github.com/robsyme)

## Support

For further information or help, don't hesitate to get in touch on the [Slack `#rnaseq` channel](https://nfcore.slack.com/channels/rnaseq) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use nf-core/rnaseq for your analysis, please cite it using the following doi: [10.5281/zenodo.1400710](https://doi.org/10.5281/zenodo.1400710)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

