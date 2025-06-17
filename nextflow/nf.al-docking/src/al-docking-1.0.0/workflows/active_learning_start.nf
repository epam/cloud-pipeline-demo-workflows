include { RUN_PREPARE_VALIDATION_SAMPLE } from '../modules/local/prepare_validation_sample'
include { metaReceptor                  } from '../libs/meta'

workflow ACTIVE_LEARNING_START {
    take:
    receptor
    compound_db

    main:
    // receptor.dump(tag: "ACTIVE_LEARNING_START receptor", pretty: true)

    def receptor_initial = receptor.filter { it.iteration_num == 0 }
    def receptor_resumed = receptor.filter { it.iteration_num > 0 }

    RUN_PREPARE_VALIDATION_SAMPLE(
        receptor_initial.map { metaReceptor(it) },
        receptor_initial.map { it.iterations_path },
        compound_db,
        params.validation_sample_size,
    )

    def receptor_started = RUN_PREPARE_VALIDATION_SAMPLE.out
        .map { meta, valid, unlabeled ->
            [meta.id, [valid: valid, unlabeled: unlabeled, iteration_num: 0]]
        }
        .join(receptor_initial.map { [it.id, it] }, by: 0)
        .map { it[2] + it[1] }

    def res_receptor = receptor_started.mix(receptor_resumed)
    // res_receptor.dump(tag: "ACTIVE_LEARNING_START res_receptor", pretty: true)

    emit:
    receptor = res_receptor
}
