/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ASSEMBLYSCAN                             } from '../modules/nf-core/assemblyscan/main'
include { LAST_MAFCONVERT as ALIGNMENT_CRAM        } from '../modules/nf-core/last/mafconvert/main'
include { LAST_MAFCONVERT as ALIGNMENT_EXP         } from '../modules/nf-core/last/mafconvert/main'
include { SAMTOOLS_MERGE as ALIGNMENT_MERGE        } from '../modules/nf-core/samtools/merge/main'
include { LAST_DOTPLOT as MULTIQC_THUMBS           } from '../modules/nf-core/last/dotplot/main'
include { MULTIQC_THUMBS_HTML                      } from '../modules/local/multiqc_thumbs_html/main'
include { MULTIQC_ASSEMBLYSCAN_PLOT_DATA           } from '../modules/local/multiqc_assemblyscan_plot_data/main'
include { PAIRALIGN_M2M                            } from '../subworkflows/local/pairalign_m2m/main'
include { SEQTK_CUTN as TARGETGENOME_CUTN          } from '../modules/nf-core/seqtk/cutn/main'
include { SEQTK_CUTN as CUTN_QUERY                 } from '../modules/nf-core/seqtk/cutn/main'
include { PAIRALIGN_M2O                            } from '../subworkflows/local/pairalign_m2o/main'
include { MULTIQC                                  } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                         } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { FASTA_BGZIP_INDEX_DICT_SAMTOOLS          } from '../subworkflows/nf-core/fasta_bgzip_index_dict_samtools/main'
include { methodsDescriptionText                   } from '../subworkflows/local/utils_nfcore_pairgenomealign_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PAIRGENOMEALIGN {

    take:
    ch_samplesheet  // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    ch_targetgenome = ch_samplesheet.map { meta, query, target -> [ [id:meta.targetName], target ] }.first()
    ch_querygenome  = ch_samplesheet.map { meta, query, target -> [ meta, query ] }

    ch_targetgenome_indexed = ch_targetgenome.map { meta, target -> [ meta, target, [], [], [], [] ]  }
    export_formats = params.export_aln_to.tokenize(',')
    def needs_genome = ['cram','bam','bcf','gff'].any { export_formats.contains(it) }
    if (params.multi_cram || needs_genome) {
        FASTA_BGZIP_INDEX_DICT_SAMTOOLS( ch_targetgenome.map { meta, target -> [[id:meta.id + '.fasta'], target] } )
        ch_targetgenome_indexed = FASTA_BGZIP_INDEX_DICT_SAMTOOLS.out.fasta_fai_gzi_dict.first()
    }

    // Extract coordinates of poly-N regions; they are often contig boundaries in scaffolds
    //
    TARGETGENOME_CUTN (
        ch_targetgenome.map { meta, target -> [[id:meta.id + '.cuts'], target] }
    )
    CUTN_QUERY (
        ch_querygenome
    )

    // Allow to skip statistics on contig length and GC content
    //
    if (! params.skip_assembly_qc ) {
        ASSEMBLYSCAN ( ch_querygenome )
        assemblyscan_sorted_json_files = ASSEMBLYSCAN.out.report
          .toSortedList { a, b -> a[0].id <=> b[0].id }
          .map { sorted_list -> sorted_list.collect { it[1] } }
        // Sorted input is needed for stable MD5 output
        MULTIQC_ASSEMBLYSCAN_PLOT_DATA ( assemblyscan_sorted_json_files )
        ch_multiqc_files = ch_multiqc_files.mix(MULTIQC_ASSEMBLYSCAN_PLOT_DATA.out.tsv)
    }

    // Prefix query ids with target genome name before producing alignment files
    //
    def pair_id_prefix = "${params.targetName}___"
    ch_querygenome_pairnames = ch_querygenome
        .map { row -> [ [id: pair_id_prefix + row[0].id] , row.tail() ] }
    ch_seqtk_cutn_query = CUTN_QUERY.out.bed
        .map { row -> [ [id: pair_id_prefix + row[0].id] , row.tail() ] }

    // Align with either the many-to-many or the many-to-one subworkflow
    // and collect the output under a fixed name
    //
    if (!(params.m2m)) {
        PAIRALIGN_M2O (
            ch_targetgenome,
            ch_querygenome_pairnames,
            TARGETGENOME_CUTN.out.bed,
            ch_seqtk_cutn_query
        )
        pairalign_out = PAIRALIGN_M2O.out
    } else {
        PAIRALIGN_M2M (
            ch_targetgenome,
            ch_querygenome_pairnames,
            TARGETGENOME_CUTN.out.bed,
            ch_seqtk_cutn_query
        )
        pairalign_out = PAIRALIGN_M2M.out
    }

    if (!(params.export_aln_to == "no_export")) {
        ALIGNMENT_EXP(
            pairalign_out.o2o.combine(channel.fromList(export_formats)),
            ch_targetgenome_indexed
        )
    }

    if (params.multi_cram) {
        // We want the read group IDs to be just the query genome name (which is already long enough).
        o2o_alignments = pairalign_out.o2o.map { meta, alns ->
            def newMeta = meta.clone()    // Avoids unexpected propagation to pairalign_out.o2o's meta.id.
            newMeta.id = newMeta.id.replaceAll(/^.*___/, '')
            [newMeta, alns]
        }
        ALIGNMENT_CRAM(
            o2o_alignments.map {it + "cram"},
            ch_targetgenome_indexed
        )
        // Collect all per-query CRAMs into a single merged CRAM per target genome
        ch_merge_input = ALIGNMENT_CRAM.out.alignment
            // Rename and use as grouping key
            .map { meta, cram -> tuple(params.targetName, cram) }
            // group all CRAMs
            .groupTuple()
            // convert to SAMTOOLS_MERGE input format
            .map { id, crams -> tuple([id: id], crams, []) }
        // Output a single CRAM file under the target genome name.
        ALIGNMENT_MERGE(
            ch_merge_input,
            ch_targetgenome_indexed.map { meta, fasta, fai, gzi, _sizes, _dict -> [meta, fasta, fai, gzi ] },
        )
    }

    if (params.multiqc_thumbs != 0) {
        MULTIQC_THUMBS(
            pairalign_out.o2o.map { x -> [x[0], x[1], []] },
            [[],[]],
            "png",
            params.dotplot_filter
        )
        MULTIQC_THUMBS_HTML(
            MULTIQC_THUMBS.out.plot
                .map { meta, file -> file }
                .collect(),
            params.multiqc_thumbs
        )
        ch_multiqc_files = ch_multiqc_files.mix(MULTIQC_THUMBS_HTML.out.html)
    }

    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'pairgenomealign_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files
        .mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
        .mix(pairalign_out.multiqc)
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'pairgenomealign'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
