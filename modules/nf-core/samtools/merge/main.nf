process SAMTOOLS_MERGE {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/62/62292ffa3ecc9230d6ad20b2537a2f4434a08908864c4c2c66f2d8667f031924/data'
        : 'community.wave.seqera.io/library/bcftools_last_samtools_bzip2_pruned:562cda40b12e94c1'}"

    input:
    tuple val(meta), path(input_files, stageAs: "?/*"), path(index_files, stageAs: "?/*")
    tuple val(meta2), path(fasta), path(fai), path(gzi)

    output:
    tuple val(meta), path("${prefix}.bam"), optional: true, emit: bam
    tuple val(meta), path("${prefix}.cram"), optional: true, emit: cram
    tuple val(meta), path("*.{bai,crai,csi}"), optional: true, emit: index
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions_samtools

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def file_type = input_files instanceof List ? input_files[0].getExtension() : input_files.getExtension()
    // In this pipeline we know that the input CRAM files have a correct relative path to the reference, and we want to keep it.
    // Passing --reference transforms the link to an absolute path containing temporary folder path.
    def reference = ""
    """
    # Note: --threads value represents *additional* CPUs to allocate (total CPUs = 1 + --threads).
    samtools \\
        merge \\
        --threads ${task.cpus - 1} \\
        ${args} \\
        ${reference} \\
        ${prefix}.${file_type} \\
        ${input_files}
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def file_type = input_files instanceof List ? input_files[0].getExtension() : input_files.getExtension()
    def index_type = file_type == "bam" ? "csi" : "crai"
    def index = args.contains("--write-index") ? "touch ${prefix}.${index_type}" : ""
    """
    touch ${prefix}.${file_type}
    ${index}
    """
}
