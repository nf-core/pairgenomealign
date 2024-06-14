process CUSTOMMODULE {
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/last:1453--h5b5514e_0':
        'biocontainers/last:1453--h5b5514e_0' }"


    input:
    path(json)

    output:
    path "gc_cont_summary_mqc.tsv",  emit: tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    echo "id\tpercent_A\tpercent_C\tpercent_G\tpercent_T" > gc_cont_summary_mqc.tsv
    for i in $json
    do
      printf "\$(basename \$i _mqc.json)\t" >> gc_cont_summary_mqc.tsv
      grep contig_percent_a \$i | awk '{print \$2}' | sed -e 's/"//' -e 's/".*//' | tr '\n' '\t' >> gc_cont_summary_mqc.tsv
      grep contig_percent_c \$i | awk '{print \$2}' | sed -e 's/"//' -e 's/".*//' | tr '\n' '\t' >> gc_cont_summary_mqc.tsv
      grep contig_percent_g \$i | awk '{print \$2}' | sed -e 's/"//' -e 's/".*//' | tr '\n' '\t' >> gc_cont_summary_mqc.tsv
      grep contig_percent_t \$i | awk '{print \$2}' | sed -e 's/"//' -e 's/".*//' >> gc_cont_summary_mqc.tsv
    done
    """
}
