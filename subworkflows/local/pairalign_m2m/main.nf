/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_M2O     } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_M2O_FLT } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_M2M     } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_M2M_FLT } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_O2O     } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_O2O_FLT } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_O2M     } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_DOTPLOT as ALIGNMENT_DOTPLOT_O2M_FLT } from '../../../modules/nf-core/last/dotplot/main'
include { LAST_LASTAL  as ALIGNMENT_LASTAL_M2M      } from '../../../modules/nf-core/last/lastal/main'
include { LAST_LASTDB  as ALIGNMENT_LASTDB          } from '../../../modules/nf-core/last/lastdb/main'
include { LAST_SPLIT   as ALIGNMENT_SPLIT_M2O       } from '../../../modules/nf-core/last/split/main'
include { LAST_SPLIT   as ALIGNMENT_SPLIT_O2O       } from '../../../modules/nf-core/last/split/main'
include { LAST_SPLIT   as ALIGNMENT_SPLIT_O2M       } from '../../../modules/nf-core/last/split/main'
include { LAST_TRAIN   as ALIGNMENT_TRAIN           } from '../../../modules/nf-core/last/train/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PAIRALIGN_M2M {

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

    // Train alignment parameters if not provided
    //
    if (params.lastal_params) {
        ch_queries_with_params = ch_queries.map { row -> [ row[0], row[1], file(params.lastal_params, checkIfExists: true) ] }
        training_results_for_multiqc = channel.empty()
    } else {
        ALIGNMENT_TRAIN (
            ch_queries,
            ALIGNMENT_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
        )
        ch_queries_with_params = ch_queries.join(ALIGNMENT_TRAIN.out.param_file)
        training_results_for_multiqc = ALIGNMENT_TRAIN.out.multiqc.collect{ it[1] }
    }

    // Align queries to target.  This is a many-to-many alignment
    //
    ALIGNMENT_LASTAL_M2M (
        ch_queries_with_params,
        ALIGNMENT_LASTDB.out.index.map { row -> row[1] }  // Remove metadata map
    )

    // Optionally plot the many-to-many alignment
    //
    if (! (params.skip_dotplot_m2m) ) {
        ALIGNMENT_DOTPLOT_M2M (
            ALIGNMENT_LASTAL_M2M.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png',
            []
        )
        if ( params.dotplot_filter ) {
            ALIGNMENT_DOTPLOT_M2M_FLT (
                ALIGNMENT_LASTAL_M2M.out.maf.join(ch_queries_bed),
                ch_target_bed,
                'png',
                true
            )
        }
    }

    // Compute the one-to-many alignment and optionally plot it
    //
    ALIGNMENT_SPLIT_O2M (
        ALIGNMENT_LASTAL_M2M.out.maf
    )
    if (! (params.skip_dotplot_o2m) ) {
        ALIGNMENT_DOTPLOT_O2M (
            ALIGNMENT_SPLIT_O2M.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png',
            []
        )
        if ( params.dotplot_filter ) {
            ALIGNMENT_DOTPLOT_O2M_FLT (
                ALIGNMENT_SPLIT_O2M.out.maf.join(ch_queries_bed),
                ch_target_bed,
                'png',
                true
            )
        }
    }

    // Compute the many-to-one alignment and optionally plot it
    //
    ALIGNMENT_SPLIT_M2O (
        ALIGNMENT_LASTAL_M2M.out.maf
    )
    if (! (params.skip_dotplot_m2o) ) {
        ALIGNMENT_DOTPLOT_M2O (
            ALIGNMENT_SPLIT_M2O.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png',
            []
        )
        if ( params.dotplot_filter ) {
            ALIGNMENT_DOTPLOT_M2O_FLT (
                ALIGNMENT_SPLIT_M2O.out.maf.join(ch_queries_bed),
                ch_target_bed,
                'png',
                true
            )
        }
    }

    // Compute the one-to-one alignment and optionally plot it
    //
    ALIGNMENT_SPLIT_O2O (
        ALIGNMENT_SPLIT_M2O.out.maf
    )
    if (! (params.skip_dotplot_o2o) ) {
        ALIGNMENT_DOTPLOT_O2O (
            ALIGNMENT_SPLIT_O2O.out.maf.join(ch_queries_bed),
            ch_target_bed,
            'png',
            []
        )
        if ( params.dotplot_filter ) {
            ALIGNMENT_DOTPLOT_O2O_FLT (
                ALIGNMENT_SPLIT_O2O.out.maf.join(ch_queries_bed),
                ch_target_bed,
                'png',
                true
            )
        }
    }

    emit:

    multiqc = channel.empty()
        .mix(training_results_for_multiqc)
        .mix(ALIGNMENT_SPLIT_O2O.out.multiqc.collect{ it[1]} )
    m2m = ALIGNMENT_LASTAL_M2M.out.maf
    m2o = ALIGNMENT_SPLIT_M2O.out.maf
    o2m = ALIGNMENT_SPLIT_O2M.out.maf
    o2o = ALIGNMENT_SPLIT_O2O.out.maf
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
