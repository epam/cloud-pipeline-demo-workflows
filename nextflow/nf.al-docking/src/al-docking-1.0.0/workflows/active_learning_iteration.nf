include { RUN_SPLIT_TRAINING_SAMPLE                     } from '../modules/local/active_learning_iteration/00.split_training_sample'
include { RUN_CALC_FINGERPRINT                          } from '../modules/local/active_learning_iteration/05.calc_fingerprint'
include { DOCKING                                       } from '../subworkflows/local/docking'
include { RUN_TRAIN_MODEL                               } from '../modules/local/training/train_model'
include { INFER_UNLABELED                               } from '../subworkflows/local/infer_unlabeled'
include { INFER_UNLABELED_CHUNKS                        } from '../subworkflows/local/infer_unlabeled_chunks'
include { RUN_SAVE_ITERATION_DATA                       } from '../modules/local/active_learning_iteration/10.save_iteration_data'
include { iterToStr                                     } from '../libs/utils'
include { RUN_INFER_UNLABELED as RUN_INFER_VALID_BEFORE } from '../modules/local/inference/infer_unlabeled'
include { RUN_INFER_UNLABELED as RUN_INFER_VALID        } from '../modules/local/inference/infer_unlabeled'
include { RUN_INFER_UNLABELED as RUN_INFER_TRAIN_BEFORE } from '../modules/local/inference/infer_unlabeled'
include { RUN_INFER_UNLABELED as RUN_INFER_TRAIN        } from '../modules/local/inference/infer_unlabeled'
include { RUN_INFER_UNLABELED as RUN_INFER_TEST_BEFORE  } from '../modules/local/inference/infer_unlabeled'
include { RUN_INFER_UNLABELED as RUN_INFER_TEST         } from '../modules/local/inference/infer_unlabeled'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_VALID_DOCKED  } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_VALID_BEFORE  } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_VALID         } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_TRAIN_BEFORE  } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_TRAIN         } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_TEST_BEFORE   } from '../modules/local/utils/publish_file'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_TEST          } from '../modules/local/utils/publish_file'
include { metaLigands                                   } from '../libs/meta'
include { metaReceptor                                  } from '../libs/meta'

workflow ACTIVE_LEARNING_ITERATION {
    take:
    receptor

    main:
    def dummy_fn = "${projectDir}/assets/NO_FILE.ext"
    // receptor.dump(tag: 'ACTIVE_LEARNING_ITERATION receptor', pretty: true)

    // println("######## ACTIVE_LEARNING_ITERATION 1")
    RUN_SPLIT_TRAINING_SAMPLE(
        receptor.map { metaReceptor(it) },
        receptor.map { [it.unlabeled ?: dummy_fn, it.inferred ?: dummy_fn] },
        receptor.map { it.iterations_path },
    )
    // println("######## ACTIVE_LEARNING_ITERATION 2")
    def receptor_ch = RUN_SPLIT_TRAINING_SAMPLE.out
        .map { meta, train, test, unlabeled -> [meta.id, [train: train, test: test, unlabeled: unlabeled]] }
        .join(receptor.map { [it.id, it] }, by: 0)
        .map { it[2] + it[1] }
    // receptor_split_ch.dump(tag: "ACTIVE_LEARNING_ITERATION receptor_ch splitted", pretty: true)

    // println("######## ACTIVE_LEARNING_ITERATION 3")
    def ligands_in_all = receptor_ch
        .map { it + [ligands_csv: it.train, role: 'train'] }
        .mix(receptor_ch.map { it + [ligands_csv: it.test, role: 'test'] })
        .mix(
            receptor_ch.map {
                it.iteration_num == 0
                    ? it + [ligands_csv: it.valid, role: 'valid']
                    : null
            }
        )
        .filter { it != null }
    // ligands_in_all.dump(tag: 'ACTIVE_LEARNING_ITERATION ligands_in_all', pretty: true)
    def ligands_in = ligands_in_all.map { it.findAll { k, _v -> !(k in ['train', 'test', 'valid']) } }
    // ligands_in.dump(tag: "ACTIVE_LEARNING_ITERATION ligands_in", pretty: true)

    // RUN_CALC_FINGERPRINT(
    //     ligands_in.map { [[id: it.id, role: it.role], it.iteration_num, it.ligands_csv] },
    //     ligands_in.map { it.iterations_path },
    //     ligands_in.map { it.cache_path },
    // )
    // // println("######## ACTIVE_LEARNING_ITERATION 4")
    // def ligands_fp = RUN_CALC_FINGERPRINT.out
    //     .map { [it[0].id, it[0].role, [fp: it[1]]] }
    //     .join(ligands_in.map { [it.id, it.role, it] }, by: [0, 1])
    //     .map { it[3] + it[2] }
    // // ligands_fp.dump(tag: "ACTIVE_LEARNING_ITERATION ligands_fp", pretty: true)

    // println("######## ACTIVE_LEARNING_ITERATION 5")
    DOCKING(ligands_in)
    def receptor_docked = DOCKING.out.ligands
        .map {
            def cit = it.findAll { k, _v -> !k.startsWith('ligands') && !(k in ['id', 'iteration_num', 'role']) }
            def cit_train = it.role == 'train' ? [train_docked_csv: it.ligands_docked_csv] : []
            def cit_test = it.role == 'test' ? [test_docked_csv: it.ligands_docked_csv] : []
            def cit_valid = it.role == 'valid' ? [valid_docked_csv: it.ligands_docked_csv] : []
            def key = groupKey(metaReceptor(it).key(), it.iteration_num == 0 ? 3 : 2)
            return [key, cit + cit_train + cit_test + cit_valid]
        }
        .groupTuple(by: 0)
        .map { [id: it[0][1], iteration_num: it[0][0]] + it[1][0] + it[1][1] + (it[1].size() == 3 ? it[1][2] : []) }
    // receptor_docked.dump(tag: "ACTIVE_LEARNING_ITERATION receptor_docked", pretty: true)

    RUN_INFER_VALID_BEFORE(
        receptor_docked.map { [metaReceptor(it), '.before-inferred'] },
        receptor_docked.map { it.valid_docked_csv },
        receptor_docked.map { it.model_pth ?: dummy_fn },
        receptor_docked.map { it.iterations_path },
        receptor_docked.map { it.cache_path },
    )
    RUN_INFER_TRAIN_BEFORE(
        receptor_docked.map { [metaReceptor(it), '.before-inferred'] },
        receptor_docked.map { it.train_docked_csv },
        receptor_docked.map { it.model_pth ?: dummy_fn },
        receptor_docked.map { it.iterations_path },
        receptor_docked.map { it.cache_path },
    )
    RUN_INFER_TEST_BEFORE(
        receptor_docked.map { [metaReceptor(it), '.before-inferred'] },
        receptor_docked.map { it.test_docked_csv },
        receptor_docked.map { it.model_pth ?: dummy_fn },
        receptor_docked.map { it.iterations_path },
        receptor_docked.map { it.cache_path },
    )

    RUN_TRAIN_MODEL(
        receptor_docked.map { metaReceptor(it) },
        receptor_docked.map { it.model_pth ?: dummy_fn },
        receptor_docked.map { it.train_docked_csv },
        receptor_docked.map { it.test_docked_csv },
        receptor_docked.map { it.iterations_path },
        receptor_docked.map { it.cache_path },
    )
    receptor_model = RUN_TRAIN_MODEL.out
        .map { meta, model_pth ->
            [meta.key(), [model_pth: model_pth]]
        }
        .join(
            receptor_docked.map { [metaReceptor(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // receptor_model.dump(tag: "ACTIVE_LEARNING_ITERATION receptor_model", pretty: true)

    INFER_UNLABELED_CHUNKS(receptor_model)
    RUN_INFER_VALID(
        receptor_model.map { [metaReceptor(it), '.inferred'] },
        receptor_model.map { it.valid_docked_csv },
        receptor_model.map { it.model_pth },
        receptor_model.map { it.iterations_path },
        receptor_model.map { it.cache_path },
    )
    RUN_INFER_TRAIN(
        receptor_model.map { [metaReceptor(it), '.inferred'] },
        receptor_model.map { it.train_docked_csv },
        receptor_model.map { it.model_pth },
        receptor_model.map { it.iterations_path },
        receptor_model.map { it.cache_path },
    )
    RUN_INFER_TEST(
        receptor_model.map { [metaReceptor(it), '.inferred'] },
        receptor_model.map { it.test_docked_csv },
        receptor_model.map { it.model_pth },
        receptor_model.map { it.iterations_path },
        receptor_model.map { it.cache_path },
    )
    def receptor_inferred = INFER_UNLABELED_CHUNKS.out.receptor_inferred
        .map { [metaReceptor(it).key(), it] }
        .join(
            RUN_INFER_VALID_BEFORE.out.map { meta, inferred_csv ->
                [meta.key(), [valid_before_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(
            RUN_INFER_TRAIN_BEFORE.out.map { meta, inferred_csv ->
                [meta.key(), [train_before_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(
            RUN_INFER_TEST_BEFORE.out.map { meta, inferred_csv ->
                [meta.key(), [test_before_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(
            RUN_INFER_VALID.out.map { meta, inferred_csv ->
                [meta.key(), [valid_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(
            RUN_INFER_TRAIN.out.map { meta, inferred_csv ->
                [meta.key(), [train_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(
            RUN_INFER_TEST.out.map { meta, inferred_csv ->
                [meta.key(), [test_inferred_csv: inferred_csv]]
            },
            by: 0
        )
        .join(receptor_model.map { [metaReceptor(it).key(), it] }, by: [0])
        .map { it[1] + it[2] + it[3] + it[4] + it[5] + it[6] + it[7] }
    // receptor_inferred.dump(tag: "ACTIVE_LEARNING_ITERATION receptor_inferred", pretty: true)

    RUN_PUBLISH_VALID_DOCKED(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.valid_docked_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_VALID_BEFORE(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.valid_before_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_TRAIN_BEFORE(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.train_before_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_TEST_BEFORE(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.test_before_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_VALID(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.valid_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_TRAIN(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.train_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    RUN_PUBLISH_TEST(
        receptor_inferred.map { metaReceptor(it) },
        receptor_inferred.map { it.test_inferred_csv },
        receptor_inferred.map { it.iterations_path },
    )
    def receptor_published = receptor_inferred
        .map { [metaReceptor(it).key(), it] }
        .join(
            RUN_PUBLISH_VALID_DOCKED.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_VALID_BEFORE.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_TRAIN_BEFORE.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_TEST_BEFORE.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_VALID.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_TRAIN.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .join(
            RUN_PUBLISH_TEST.out.map { meta, _published ->
                [meta.key(), []]
            },
            by: 0
        )
        .map { it[1] + it[2] + it[3] + it[4] + it[5] + it[6] + it[7] + it[8] }
    // receptor_published.dump(tag: "ACTIVE_LEARNING_ITERATION receptor_published", pretty: true)

    // RUN_SAVE_ITERATION_DATA(receptor_inferred)
    // res_receptor_ch = RUN_SAVE_ITERATION_DATA.out
    //     .map { meta, iteration_json ->
    //         [meta.id, [iteration_json: iteration_json]]
    //     }
    //     .join(receptor_inferred.map { [it.id, it] }, by: 0)
    //     .map { it[2] + it[1] }

    def res_receptor = receptor_published.map {
        def cit = it.findAll { k, _v ->
            !(k in [
                'unlabeled',
                'test_docked_csv',
                'train_docked_csv',
                'test_inferred_csv',
                'valid_inferred_csv',
                'valid_before_inferred_csv',
            ])
        }
        // println("######## ACTIVE_LEARNING_ITERATION res_receptor, iteration_num: ${it.iteration_num}")
        def cit_iterations = [
            "${iterToStr(it.iteration_num)}": [
                model_pth: it.model_pth,
                train_docked_csv: it.train_docked_csv,
                test_inferred_csv: it.test_inferred_csv,
                valid_before_inferred_csv: it.valid_before_inferred_csv,
                valid_inferred_csv: it.valid_inferred_csv,
            ]
        ]
        // println("######## ACTIVE_LEARNING_ITERATION res_receptor, cit_iterations: ${cit_iterations}")
        return cit + [iterations: ((it.iterations ?: []) + cit_iterations)]
    }
    // res_receptor.dump(tag: 'ACTIVE_LEARNING_ITERATION res_receptor', pretty: true)

    emit:
    receptor = res_receptor
}
