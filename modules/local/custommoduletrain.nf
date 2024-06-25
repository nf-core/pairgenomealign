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
    echo "id\tsubstitution percent identity" > sub%id_mqc.tsv
    for i in $param_file
    do
        printf "\$(basename \$i _mqc.json)\t" >> sub%id_mqc.tsv
        grep 'substitution percent identity' \$i | tail -n 1 | awk '{print \$5}' >> sub%id_mqc.tsv
    done

    echo "id\tlast -a\tlast -A\tlast -b\tlast -B\tlast -S" > lastid_mqc.tsv
    for i in $param_file
    do
        printf "\$(basename \$i _mqc.json)\t" >> lastid_mqc.tsv
        grep 'last -a' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -A' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -b' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -B' \$i | tail -n 1 | awk '{print \$3}' | tr '\n' '\t' >> lastid_mqc.tsv
        grep 'last -S' \$i | tail -n 1 | awk '{print \$3}' >> lastid_mqc.tsv
    done
    """
}
