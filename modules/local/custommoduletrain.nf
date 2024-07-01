process CUSTOMMODULETRAIN {
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/last:1542--h43eeafb_1':
        'biocontainers/last:1542--h43eeafb_1' }"


    input:
    path(param_file)

    output:
    path "*_mqc.tsv",  emit: tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    echo "# id: 'alignment parameters'" > lastid_mqc.tsv
    echo "# section_name: 'Alignment parameters and summary'" >> lastid_mqc.tsv
    echo "# format: 'tsv'" >> lastid_mqc.tsv
    echo "# plot_type: 'table'" >> lastid_mqc.tsv
    echo "# description: 'This plot shows the last alignment parameters'" >> lastid_mqc.tsv
    echo "# pconfig:" >> lastid_mqc.tsv
    echo "#    id: 'alingment parameters'" >> lastid_mqc.tsv
    echo "#    title: 'alingment parameters'" >> lastid_mqc.tsv
    echo "#    ylab: ''" >> lastid_mqc.tsv
    echo "id\tsubstitution_percent_identity\tlast -t\tlast -a\tlast -A\tlast -b\tlast -B\tlast -S" >> lastid_mqc.tsv
    for i in $param_file
    do
        printf "\$(basename \$i .target.train)\t" >> lastid_mqc.tsv
        grep 'substitution percent identity' \$i | tail -n 1 | awk '{print \$5}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -t' \$i | tail -n 1 | awk '{print \$2}' | sed -e 's/-t//' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -a' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -A' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -b' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -B' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -S' \$i | tail -n 1 | awk '{print \$3}' >> lastid_mqc.tsv
    done
    """
}
