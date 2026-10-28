process MULTIQC_ASSEMBLYSCAN_PLOT_DATA {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/84/84eef7b4cd5f6304aa5ba9ac6b0051850af300abefb615b72b776d1245990749/data'
        : 'community.wave.seqera.io/library/jq:fee8aafd41d9e3aa' }"

    // This module parses the JSON output of the assemblyscan module with jq to extract
    // statistics about GC content and contig length.  I do not know how to contribute
    // this as a proper MultiQC module but feel free to do so!

    input:
    path(json)

    output:
    path ("*_mqc.tsv") ,  emit: tsv
    tuple val("${task.process}"), val('jq'), eval("jq --version 2>&1 | sed 's/jq-//'"), emit: versions_jq, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    echo "# id: 'base_content_summary'" > gc_summary_mqc.tsv
    echo "# section_name: 'Base frequency'" >> gc_summary_mqc.tsv
    echo "# format: 'tsv'" >> gc_summary_mqc.tsv
    echo "# plot_type: 'bargraph'" >> gc_summary_mqc.tsv
    echo "# description: 'Base frequency (in percent) in the query genomes'" >> gc_summary_mqc.tsv
    echo "# pconfig:" >> gc_summary_mqc.tsv
    echo "#    id: 'base_content_summary_plot'" >> gc_summary_mqc.tsv
    echo "#    title: 'Per-base percentage'" >> gc_summary_mqc.tsv
    echo "#    ylab: ''" >> gc_summary_mqc.tsv
    echo "id\tpercent A\tpercent C\tpercent G\tpercent T\tpercent N\tpercent non-ACGTN" >> gc_summary_mqc.tsv
    for i in ${json}
    do
        printf "\$(basename \$i .json)\t" >> gc_summary_mqc.tsv
        jq -r '[.contig_percent_a, .contig_percent_c, .contig_percent_g, .contig_percent_t, .contig_percent_n, .contig_non_acgtn] | @tsv' \$i >> gc_summary_mqc.tsv
    done

    echo "# id: 'contigs_length_statistics'" > contig_length_mqc.tsv
    echo "# section_name: 'Contig length statistics'" >> contig_length_mqc.tsv
    echo "# format: 'tsv'" >> contig_length_mqc.tsv
    echo "# plot_type: 'table'" >> contig_length_mqc.tsv
    echo "# description: 'Contigs length statistic for the query genomes, collected with assembly-scan'" >> contig_length_mqc.tsv
    echo "# pconfig:" >> contig_length_mqc.tsv
    echo "#    id: 'contigs_length_statistics_plot'" >> contig_length_mqc.tsv
    echo "#    title: 'Contigs length statistics'" >> contig_length_mqc.tsv
    echo "#    ylab: 'length'" >> contig_length_mqc.tsv
    echo "id\tTOTAL contig len.\tMin contig len.\tMAX contig len.\tTotal contigs\tContigs > 1k\tContigs > 10k" >> contig_length_mqc.tsv
    for i in ${json}
    do
        printf "\$(basename \$i .json)\t" >> contig_length_mqc.tsv
        jq -r '[.total_contig_length, .min_contig_length, .max_contig_length, .total_contig, .contigs_greater_1k, .contigs_greater_10k] | @tsv' \$i >> contig_length_mqc.tsv
    done
    """

    stub:
    """
    touch gc_summary_mqc.tsv
    touch contig_length_mqc.tsv
    """
}
