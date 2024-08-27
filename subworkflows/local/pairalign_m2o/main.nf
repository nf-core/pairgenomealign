/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_M2O } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_O2O } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_LASTAL  as ALIGNMENT_LASTAL_M2O  } from '../../../modules/nf-core/last/lastal/main'
include { LAST_LASTDB  as ALIGNMENT_LASTDB      } from '../../../modules/nf-core/last/lastdb/main'
include { LAST_SPLIT   as ALIGNMENT_SPLIT_O2O   } from '../../../modules/nf-core/last/split/main'
include { LAST_TRAIN   as ALIGNMENT_TRAIN       } from '../../../modules/nf-core/last/train/main'

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

    // Index the target genome
    //
    ALIGNMENT_LASTDB (
        ch_target
    )

    // Train alignment parameters
    //
    ALIGNMENT_TRAIN (
        ch_queries,
        ALIGNMENT_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // Align queries to target.
    // This directly computes a many-to-one alignment because of parameter modules
    //
    ALIGNMENT_LASTAL_M2O (
        ch_queries.join(ALIGNMENT_TRAIN.out.param_file),
        ALIGNMENT_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // Optionally plot the many-to-one alignment
    //
    if (! (params.skip_dotplot_m2o) ) {
        ALIGNMENT_DOTPLOT_M2O (
            ALIGNMENT_LASTAL_M2O.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png'
        )
    }

    // Compute the one-to-one alignment and optionally plot it
    //
    ALIGNMENT_SPLIT_O2O (
        ALIGNMENT_LASTAL_M2O.out.maf
    )
    if (! (params.skip_dotplot_o2o) ) {
        ALIGNMENT_DOTPLOT_O2O (
            ALIGNMENT_SPLIT_O2O.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png'
        )
    }

    emit:

    multiqc = Channel.empty()
        .mix(    ALIGNMENT_TRAIN.out.multiqc.collect{ it[1]} )
        .mix(ALIGNMENT_SPLIT_O2O.out.multiqc.collect{ it[1]} )
    m2o = ALIGNMENT_LASTAL_M2O.out.maf
    o2o = ALIGNMENT_SPLIT_O2O.out.maf
    versions = ALIGNMENT_LASTDB.out.versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
