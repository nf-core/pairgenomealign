/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LAST_DOTPLOT as LAST_DOTPLOT_M2O          } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as LAST_DOTPLOT_O2O          } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_LASTAL as LAST_LASTAL_M2O           } from '../../../modules/nf-core/last/lastal/main'
include { LAST_LASTDB            } from '../../../modules/nf-core/last/lastdb/main'
include { LAST_SPLIT as LAST_SPLIT_O2O             } from '../../../modules/nf-core/last/split/main'
include { LAST_TRAIN             } from '../../../modules/nf-core/last/train/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PAIRALIGN_M2O {

    take:
    ch_target       // channel: target file read in from --target
    ch_queries      // channel: query sequences found in samplesheet read in from --input
    ch_target_bed   // channel: position of poly-N stretches in the target genome
    ch_queries_bed  // channel: position of poly-N stretches in the query genomes

    main:

    //
    // MODULE: lastdb
    //
    LAST_LASTDB (
        ch_target
    )

    // MODULE: last-train
    //
    LAST_TRAIN (
        ch_queries,
        LAST_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // MODULE: lastal_lastal_m2o
    //
    LAST_LASTAL_M2O (
        ch_queries.join(LAST_TRAIN.out.param_file),
        LAST_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // MODULE: last_dotplot_m2o
    //
    if (! (params.skip_dotplot_m2o) ) {
    LAST_DOTPLOT_M2O (
        LAST_LASTAL_M2O.out.maf.join(ch_queries_bed),
        ch_target_bed,
        'png'
    )
    }

    // MODULE: last_split_o2o
    // with_arg
    //
    LAST_SPLIT_O2O (
        LAST_LASTAL_M2O.out.maf
    )

    // MODULE: last_dotplot_o2o
    //
    if (! (params.skip_dotplot_o2o) ) {
    LAST_DOTPLOT_O2O (
        LAST_SPLIT_O2O.out.maf.join(ch_queries_bed),
        ch_target_bed,
        'png'
    )
    }

    emit:

    multiqc = Channel.empty()
        .mix(    LAST_TRAIN.out.multiqc.collect{ it[1]} )
        .mix(LAST_SPLIT_O2O.out.multiqc.collect{ it[1]} )
    m2o = LAST_LASTAL_M2O.out.maf
    o2o = LAST_SPLIT_O2O.out.maf
    versions = LAST_LASTDB.out.versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
