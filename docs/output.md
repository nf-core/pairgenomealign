# nf-core/pairgenomealign: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Alignments](#alignments) - Alignment of the _query_ genomes to the _target_ genome
- [Dot plots](#dot-plots) - Visualisation of the alignment of the _query_ genomes to the _target_ genome
- [`N` regions](#n-regions) - Coordinate of the `N` regions on the _query_ and _target_ genomes
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

Each _query_ genome, is aligned to the _target_ genome, and each alignment is visualised with dot plots. The output file names are constructed by concatenating the _target_ and _query_ sample identifiers with a `___` separator (three underscores), to faciliate re-extraction of the IDs from file names.

### Assembly statistics

<details markdown="1">
<summary>Output files</summary>

- `assemblyscan/`
  - `*.json` contains the statistics collected with the [`assembly-scan`](https://github.com/rpetit3/assembly-scan) software.

</details>

Basic statistics on nucleotide content and contig length are collected for aligned genome for later plotting with MultiQC.

### Alignments

<details markdown="1">
<summary>Output files</summary>

- `alignment/`
  - `*.train` is the alignment parameters computed by `last-train` (optional)
  - `*.train.tsv` reports some of the parameters computed by `last-train` for MultiQC (optional)
  - `*.m2m.maf.gz` is the _**many-to-many**_ alignment between _target_ and _query_ genomes. (optional through the `--m2m` option)
  - `*.m2o.maf.gz` is the _**many-to-one**_ alignment regions of the _target_ genome are matched at most once by the _query_ genome. (optional through the `--m2m` option)
  - `*.o2m.maf.gz` is the _**one-to-many**_ alignment between the _target_ and _query_ genomes. (optional through the `--m2m` option)
  - `*.o2o.maf.gz` is the _**one-to-one**_ alignment between the _target_ and _query_ genomes.
  - `*.o2o.tsv` reports nucleotide percent identity of the _**one-to-one**_ alignment for MultiQC.
  - `*.o2o.matrix.txt` reports the substitution matrix and some evolutionary distance indices computed from the _**one-to-one**_ alignment for MultiQC.
  - For each _**one-to-one**_ alignment there will be an additional file in a format such as Axt, Chain, GFF or SAM/BAM/CRAM if you used the `--export_to` parameter. These extra files are always compressed with gzip when their format is text-based. The SAM/BAM/CRAM files are always sorted. Their header features all sequences from the _target_ genome, including the ones that did not align to the _query_ so that alignment files can be merged without disturbing the sort order.
  - The _target_ genome sequence, compressed with `bgzip` and indexed by `samtools` is also present when BAM or CRAM files are produced.
  - A multi-_query_ CRAM sequence is present when `--multi_cram` is used, named like the _target_ genome but with the `cram` suffix.

</details>

Genomes are aligned with [`lastal`](https://gitlab.com/mcfrith/last/-/blob/main/doc/lastal.rst) after alignment parameters have been determined with [`last-train`](https://gitlab.com/mcfrith/last/-/blob/main/doc/last-train.rst). _**Many-to-many**_ alignments are progressively converted to _**one-to-one**_ with [`last-split`](https://gitlab.com/mcfrith/last/-/blob/main/doc/last-split.rst). In a _many-to-one_ alignment, sequences from the _target_ genome can be matched multiple times. This is for instance useful when aligning a diploid or draft assembly (_query_) to a primary reference genome (_target_), or aligning a whole-genome-duplicated _query_ to a _target_ with the ancestral ploidy. Conversely, a _one-to-many_ alignment is useful when expecting multiple matches on the _query_ by the _target_. Please note also that locally duplicated regions will appear as deletions in the _one-to-one_ alignment, as it will only keep one copy.

To speed up alignment, both strands of the target genome are indexed. This doubles memory usage and may produce output files containing `-/+` alignments, which are not supported by some downstream pipelines. To disable this behavior, use `--strand forward`.

### Dot plots

<details markdown="1">
<summary>Output files</summary>

- `alignment/`
  - `*.m2m.png` (optional)
  - `*.m2o.png` (optional)
  - `*.o2m.png` (optional)
  - `*.o2o.png` (optional)

</details>

Dot plots are representing the pairwise genome alignments and produced with the [`last-dotplot`](https://gitlab.com/mcfrith/last/-/blob/main/doc/last-dotplot.rst) tool. By default, their maximal width is fixed to aproximately 1200 pixels, so that the _target_ genome is always represented at the same scale in all plots. In the one-to-one alignment example below, the `hg38` human genome (_target_) is represented on the horizontal axis and a monkey genopme (_Macaca mulatta_ accession number `GCA\_049350105.1`) on the vertical axis (_query_). Regions containing unknown (`N`) sequences are on pink background. Forward (+/+) alignments are plotted in red and reverse (+/– or –/+) in blue. _Target_ (human) contigs are displayed in their original order. _Query_ contigs (monkey) are reordered and possibly reverse-complemented to diagonalise the plot as much as possible. The names of reverse-complemented contigs are printed in blue.

![Example of a dot-plot produced by the pipeline after aligning human and macaque genomes](images/Homo_sapiens_GRCh38.p14___Macaca_mulatta_GCA_049350105.1.o2o.png "Human–Monkey comparison")

### `N` regions

<details markdown="1">
<summary>Output files</summary>

- `cutn/`
  - `targetGenome.bed`
  - `<sample>.bed`

</details>

The poly-N regions longer than 9 bases in each genome sequence often indicate contig boundaries in scaffolds. Therefore, we marked them in pale red in the dot-plots. They are detected with the`seqtk cutN` command and its output (in 3-column BED format) is provided in the `cutn` directory. Sample IDs are constructed to generate file names, except for the _target_ genome which is always called `targetGenome` to avoid filename collisions.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
    - `/multiqc_data/multiqc_train.txt`: table reporting the alignment parameters chosen by `last-train`, for each sample.
    - `multiqc_data/multiqc_last_o2o.txt`: table reporting the nucleotide percent identity in the alignments computed by `lastal`, for each sample.
  - `multiqc_plots/`: directory containing static images from the report in various formats.
  - `assemblyscan_plot_data`: GC content and contig length statistics parsed from `assemblyscan` for MultiQC with a local module.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

The example MultiQC plots below were generated on this pipeline's full test dataset, which aligns the `hg38` human genome to other primate genomes.

#### Base content

The pipeline reports the base content of every query genome, like in the example below:

![Example of a base content report for primate genomes](images/mqc_base_content_summary-pct.png "Primate genome base content")

#### Contig length statistics

Contig length statistics can be displayed by MultiQC as violin plots.

![Example of a contig length report for primate genomes](images/mqc_contigs_length_statistics.png "Contig length statistics")

#### Training parameters

Alignment parameters computed by `last-train` can be displayed by MultiQC as violin plots.

![Example of alignment parameters for primate genomes aligned to the human genome](images/mqc_train-stats.png "Alignment parameters")

#### Alignment

Alignment statistics can be displayed by MultiQC as violin plots. There is no standard way to compute nucleotide identity ([May A. 2004](https://doi.org/10.1016/j.str.2004.04.001)), therefore the pipeline reports two alternatives, including or excluding gaps from the computation.

![Example of alignment statistics for primate genomes aligned to the human genome](images/mqc_last_o2o-stats.png "Alignment statistics")

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
