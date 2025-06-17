include { RUN_INFER_UNLABELED } from '../../modules/local/inference/infer_unlabeled'
include { iterToStr           } from '../../libs/utils'
include { metaReceptor        } from '../../libs/meta'

workflow INFER_UNLABELED {
    take:
    receptor_model

    main:
    RUN_INFER_UNLABELED(
        receptor_model.map { metaReceptor(it) },
        receptor_model.map { it.unlabeled },
        receptor_model.map { it.model_pth },
        receptor_model.map { it.iterations_path },
        receptor_model.map { it.cache_path },
    )
    res_receptor_inferred = RUN_INFER_UNLABELED.out.map { meta, inferred_csv ->
        [meta.id, [inferred_csv: inferred_csv]]
    }

    emit:
    receptor_inferred = res_receptor_inferred
}
