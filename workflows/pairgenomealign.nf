/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ASSEMBLYSCAN           } from '../modules/nf-core/assemblyscan/main'
include { LAST_DOTPLOT as LAST_DOTPLOT_M2O          } from '../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as LAST_DOTPLOT_M2M          } from '../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as LAST_DOTPLOT_O2O          } from '../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as LAST_DOTPLOT_O2M          } from '../modules/nf-core/last/dotplot/main'
include { LAST_LASTAL            } from '../modules/nf-core/last/lastal/main'
include { LAST_LASTDB            } from '../modules/nf-core/last/lastdb/main'
include { LAST_SPLIT as LAST_SPLIT_M2O            } from '../modules/nf-core/last/split/main'
include { LAST_SPLIT as LAST_SPLIT_O2O             } from '../modules/nf-core/last/split/main'
include { LAST_SPLIT as LAST_SPLIT_O2M             } from '../modules/nf-core/last/split/main'
include { LAST_TRAIN             } from '../modules/nf-core/last/train/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_pairgenomealign_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PAIRGENOMEALIGN {

    take:
    ch_samplesheet  // channel: samplesheet read in from --input
    ch_targetgenome // channel: genome file read in from --target

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: lastdb
    //
    LAST_LASTDB (
        ch_targetgenome
    )

    //
    // MODULE: assembly-scan
    //
    ASSEMBLYSCAN (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(ASSEMBLYSCAN.out.json.collect{it[1]})
    ch_versions = ch_versions.mix(ASSEMBLYSCAN.out.versions.first())

    // MODULE: last-train
    //
    LAST_TRAIN (
        ch_samplesheet,
        LAST_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // MODULE: lastal
    //
    LAST_LASTAL (
        ch_samplesheet.join(LAST_TRAIN.out.param_file),
        LAST_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // MODULE: last_dotplot_m2m
    //
    if (! (params.skip_dotplot_m2m) ) {
    LAST_DOTPLOT_M2M (
        LAST_LASTAL.out.maf,
        'png'
    )
    }

    // MODULE: last_split_o2m
    // with_arg
    //
    LAST_SPLIT_O2M (
        LAST_LASTAL.out.maf
    )

    // MODULE: last_dotplot_o2m
    // with_arg
    //
    if (! (params.skip_dotplot_o2m) ) {
    LAST_DOTPLOT_O2M (
        LAST_SPLIT_O2M.out.maf,
        'png'
    )
    }

    // MODULE: last_split_m2o
    //
    LAST_SPLIT_M2O (
        LAST_LASTAL.out.maf
    )

    // MODULE: last_dotplot_m2o
    //
    if (! (params.skip_dotplot_m2o) ) {
    LAST_DOTPLOT_M2O (
        LAST_SPLIT_M2O.out.maf,
        'png'
    )
    }

    // MODULE: last_split_o2o
    // with_arg
    //
    LAST_SPLIT_O2O (
        LAST_SPLIT_M2O.out.maf
    )

    // MODULE: last_dotplot_o2o
    //
    if (! (params.skip_dotplot_o2o) ) {
    LAST_DOTPLOT_O2O (
        LAST_SPLIT_O2O.out.maf,
        'png'
    )
    }

    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
