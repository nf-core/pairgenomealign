process MULTIQC_THUMBS_HTML {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/1b/1bef8af6be88c5733461959c46ac8ef73d18f65277f62a1695d0e1633054f9c2/data'
        : 'community.wave.seqera.io/library/multiqc:1.34--db7c73dae76bc9e6'}"

    input:
    path(pngs)
    val(width)

    output:
    path("*_mqc.html"), emit: html

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    out_file="alignment_thumbs_mqc.html"

    # MultiQC headers (MUST be raw, not escaped)
    echo "<!--"                                    >  \${out_file}
    echo "id: alignment_thumbs"                    >> \${out_file}
    echo "section_name: Alignment thumbnails"      >> \${out_file}
    echo "description: Alignment thumbnail images" >> \${out_file}
    echo "-->"                                     >> \${out_file}
    # HTML content (NOT escaped)
    echo "<div>"                                   >> \${out_file}

    for img in ${pngs}; do
        name=\$(basename "\$img")
        label=\${name%.o2o_thumb.png}

        b64=\$(base64 "\$img" | tr -d '\n')

        echo "<div style='display:inline-block; margin:5px;'>" >> \${out_file}
        echo "<img src='data:image/png;base64,\${b64}' width='${width}' title='\${label}'>" >> \${out_file}
        echo "</div>" >> \${out_file}
    done

    echo "</div>"                                  >> \${out_file}
    """

    stub:
    """
    touch alignment_thumbs_mqc.html
    """
}
