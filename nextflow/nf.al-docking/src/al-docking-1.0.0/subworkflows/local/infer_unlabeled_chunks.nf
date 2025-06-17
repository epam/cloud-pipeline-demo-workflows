include { RUN_INFER_UNLABELED } from '../../modules/local/inference/infer_unlabeled'
include { RUN_SPLIT_CSV       } from '../../modules/local/utils/split_csv'
include { RUN_MERGE_CSV       } from '../../modules/local/utils/merge_csv'
include { getChunk            } from '../../libs/chunk'
include { suffixFilename      } from '../../libs/utils'
include { iterToStr           } from '../../libs/utils'
include { ensureList          } from '../../libs/utils'
include { metaReceptor        } from '../../libs/meta'
include { metaReceptorChunk   } from '../../libs/meta'

workflow INFER_UNLABELED_CHUNKS {
    take:
    receptor_model

    main:
    def receptor_model_in = receptor_model
    // receptor_model_in.dump(tag: "INFER_UNLABELED_CHUNKS receptor_model_in", pretty: true)

    RUN_SPLIT_CSV(
        receptor_model_in.map { metaReceptor(it) },
        receptor_model_in.map { it.unlabeled },
        params.inference_chunk_size,
    )
    def receptor_model_chunks = RUN_SPLIT_CSV.out
        .map { meta, files ->
            [meta.key(), [unlabeled_csv_chunks: ensureList(files)]]
        }
        .join(
            receptor_model_in.map { [metaReceptor(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // receptor_model_chunks.dump(tag: "INFER_UNLABELED_CHUNKS receptor_model_chunks", pretty: true)

    def receptor_model_chunks_in = receptor_model_chunks
        .map { it -> [metaReceptor(it), it.unlabeled_csv_chunks] }
        .flatMap { meta, files ->
            files.collect { file -> [meta.key(), [chunk: getChunk(file), unlabeled_csv_chunk: file]] }
        }
        .combine(
            receptor_model_in.map { [metaReceptor(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // receptor_model_chunks_in.dump(tag: "INFER_UNLABELED_CHUNKS receptor_model_chunks_in", pretty: true)

    RUN_INFER_UNLABELED(
        receptor_model_chunks_in.map { [metaReceptorChunk(it), ".inferred"] },
        receptor_model_chunks_in.map { it.unlabeled_csv_chunk },
        receptor_model_chunks_in.map { it.model_pth },
        receptor_model_chunks_in.map { it.iterations_path },
        receptor_model_chunks_in.map { it.cache_path },
    )
    def receptor_inferred_chunks = RUN_INFER_UNLABELED.out
    // receptor_inferred_chunks.map { it }.dump(tag: "INFER_UNLABELED_CHUNKS receptor_inferred_chunks", pretty: true)

    def receptor_inferred_merge_in = receptor_model_chunks
        .map { [metaReceptor(it).key(), [size: it.unlabeled_csv_chunks.size()]] }
        .combine(
            receptor_inferred_chunks.map { meta, inferred_csv_chunk ->
                [metaReceptor(meta.properties).key(), [chunk: meta.chunk, inferred_csv_chunk: inferred_csv_chunk]]
            },
            by: 0
        )
        .map { key, in, out ->
            tuple(groupKey(key, in.size), out)
        }
        .groupTuple(by: 0)
        .map { key, chunks ->
            def chunks_it = [
                chunks: chunks*.chunk,
                chunks_inferred_csv: chunks*.inferred_csv_chunk,
                chunks_inferred_path: [],
            ]
            return [key, chunks_it]
        }
        .join(
            receptor_model_in.map { [metaReceptor(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // receptor_inferred_merge_in.dump(tag: "INFER_UNLABELED_CHUNKS receptor_inferred_merge_in", pretty: true)

    RUN_MERGE_CSV(
        receptor_inferred_merge_in.map { metaReceptor(it) },
        receptor_inferred_merge_in.map { it.chunks_inferred_csv.sort(false) { it.getFileName().toString() } },
        receptor_inferred_merge_in.map { it.chunks_inferred_path.sort(false) { it.getFileName().toString() } },
        receptor_inferred_merge_in.map { it.iterations_path },
        receptor_inferred_merge_in.map { suffixFilename(it.unlabeled, ".inferred") },
    )
    res_receptor_inferred = RUN_MERGE_CSV.out
        .map { meta, inferred_csv, _inferred_path ->
            [meta.key(), [inferred: inferred_csv]]
        }
        .join(receptor_model_in.map { [metaReceptor(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }
    // res_receptor_inferred.dump(tag: "INFER_UNLABELED_CHUNKS res_receptor_inferred", pretty: true)

    emit:
    receptor_inferred = res_receptor_inferred
}
