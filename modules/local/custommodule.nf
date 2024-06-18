process CUSTOMMODULE {
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/jq:1.6':
        'biocontainers/jq:1.6' }"


    input:
    path(json)

    output:
    path "*_mqc.tsv",  emit: tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    echo "id\tpercent_A\tpercent_C\tpercent_G\tpercent_T\tpercent_N\tcontig_non_ACGTN" > gc_summary_mqc.tsv
    for i in $json
    do
        printf "\$(basename \$i _mqc.json)\t" >> gc_summary_mqc.tsv
        jq -r '[.contig_percent_a, .contig_percent_c, .contig_percent_g, .contig_percent_t, .contig_percent_n, .contig_non_acgtn] | @tsv' \$i >> gc_summary_mqc.tsv
    done

    echo "id\tTOTALcontiglen\tMINcontiglen\tMAXcontiglen" > contig_length_mqc.tsv
    for i in $json
    do
        printf "\$(basename \$i _mqc.json)\t" >> contig_length_mqc.tsv
        jq -r '[.total_contig_length, .min_contig_length, .max_contig_length] | @tsv' \$i >> contig_length_mqc.tsv
    done

    echo "id\ttotalcontigs\tcontigs>1k\tcontigs>10k" > contig_total_mqc.tsv
    for i in $json
    do
        printf "\$(basename \$i _mqc.json)\t" >> contig_total_mqc.tsv
        jq -r '[.total_contig, .contigs_greater_1k, .contigs_greater_10k] | @tsv' \$i >> contig_total_mqc.tsv
    done
    """
}
