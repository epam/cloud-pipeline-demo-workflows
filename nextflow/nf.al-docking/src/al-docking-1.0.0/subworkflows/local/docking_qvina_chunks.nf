include { RUN_DOCKING_QVINA } from '../../modules/local/docking/04.docking_qvina'
include { RUN_SPLIT_CSV     } from '../../modules/local/utils/split_csv'
include { RUN_MERGE_CSV     } from '../../modules/local/utils/merge_csv'
include { getChunk          } from '../../libs/chunk'
include { suffixFilename    } from '../../libs/utils'
include { ensureList        } from '../../libs/utils'
include { metaLigands       } from '../../libs/meta'
include { metaLigandsChunk  } from '../../libs/meta'

workflow DOCKING_QVINA_CHUNKS {
    take:
    ligands_pdbqt

    main:
    def ligands_pdbqt_in = ligands_pdbqt
    // ligands_pdbqt_in.dump(tag: "DOCKING_QVINA_CHUNKS ligands_pdbqt_in", pretty: true)

    // println("######## DOCKING_QVINA_CHUNKS, docking_chunk_size: ${params.docking_chunk_size}")
    RUN_SPLIT_CSV(
        ligands_pdbqt_in.map { metaLigands(it) },
        ligands_pdbqt_in.map { it.ligands_pdbqt_csv },
        params.docking_chunk_size,
    )

    def ligands_pdbqt_chunks = RUN_SPLIT_CSV.out
        .map { meta, files ->
            return [meta.key(), [ligands_pdbqt_csv_chunks: ensureList(files)]]
        }
        .join(
            ligands_pdbqt_in.map { [metaLigands(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // ligands_pdbqt_chunks.dump(tag: "DOCKING_QVINA_CHUNKS ligands_pdbqt_chunks", pretty: true)

    def ligands_pdbqt_chunks_in = ligands_pdbqt_chunks
        .map { [metaLigands(it), it.ligands_pdbqt_csv_chunks] }
        .flatMap { meta, files ->
            files.collect { file -> [meta.key(), [chunk: getChunk(file), ligands_pdbqt_csv_chunk: file]] }
        }
        .combine(
            ligands_pdbqt_in.map { [metaLigands(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // ligands_pdbqt_chunks_in.dump(tag: "DOCKING_QVINA_CHUNKS ligands_pdbqt_chunks_in", pretty: true)

    RUN_DOCKING_QVINA(
        ligands_pdbqt_chunks_in.map {
            if (!it.chunk) {
                throw new Exception("Chunk is not defined 3")
            }

            metaLigandsChunk(it)
        },
        ligands_pdbqt_chunks_in.map { [it.ligands_pdbqt_csv_chunk, it.ligands_pdbqt_path] },
        ligands_pdbqt_chunks_in.map { [it.receptor_pdbqt, it.receptor_pocket_config] },
        ligands_pdbqt_chunks_in.map { it.iterations_path },
        ligands_pdbqt_chunks_in.map { it.cache_path },
    )
    def ligands_docked_chunks = RUN_DOCKING_QVINA.out
    // ligands_docked_chunks.map { it }.dump(tag: "DOCKING_QVINA_CHUNKS ligands_docked_chunks", pretty: true)

    def ligands_docked_merge_in = ligands_pdbqt_chunks
        .map { [metaLigands(it).key(), [size: it.ligands_pdbqt_csv_chunks.size()]] }
        .combine(
            ligands_docked_chunks.map { meta, docked_csv, docked_path ->
                [metaLigands(meta.properties).key(), [chunk: meta.chunk, ligands_docked_csv: docked_csv, ligands_docked_path: docked_path]]
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
                chunks_ligand_docked_csv: chunks*.ligands_docked_csv,
                chunks_ligand_docked_path: chunks*.ligands_docked_path,
            ]
            return [key, chunks_it]
        }
        .join(ligands_pdbqt_in.map { [metaLigands(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }
    // ligands_docked_merge_in.dump(tag: "DOCKING_QVINA_CHUNKS ligands_docked_merge_in", pretty: true)

    RUN_MERGE_CSV(
        ligands_docked_merge_in.map { metaLigands(it) },
        ligands_docked_merge_in.map { it.chunks_ligand_docked_csv.sort(false) { it.getFileName().toString() } },
        ligands_docked_merge_in.map { it.chunks_ligand_docked_path.sort(false) { it.getFileName().toString() } },
        ligands_docked_merge_in.map { it.iterations_path },
        ligands_docked_merge_in.map { suffixFilename(it.ligands_pdbqt_csv, ".docked") },
    )
    res_ligands_docked = RUN_MERGE_CSV.out
        .map { meta, ligands_docked_csv, ligands_docked_path ->
            [meta.key(), [ligands_docked_csv: ligands_docked_csv, ligands_docked_path: ensureList(ligands_docked_path)]]
        }
        .join(ligands_pdbqt_in.map { [metaLigands(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }

    emit:
    ligands_docked = res_ligands_docked
}
