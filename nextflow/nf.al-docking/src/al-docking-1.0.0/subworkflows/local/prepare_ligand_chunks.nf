include { RUN_PREPARE_LIGAND } from '../../modules/local/docking/03.prepare_ligand'
include { RUN_SPLIT_CSV      } from '../../modules/local/utils/split_csv'
include { RUN_MERGE_CSV      } from '../../modules/local/utils/merge_csv'
include { getChunk           } from '../../libs/chunk'
include { suffixFilename     } from '../../libs/utils'
include { ensureList         } from '../../libs/utils'
include { metaLigands        } from '../../libs/meta'
include { metaLigandsChunk   } from '../../libs/meta'

workflow PREPARE_LIGAND_CHUNKS {
    take:
    ligands_pdb

    main:
    def ligands_pdb_in = ligands_pdb
    // ligands_pdb_in.dump(tag: "PREPARE_LIGAND_CHUNKS ligands_pdb_in", pretty: true)

    RUN_SPLIT_CSV(
        ligands_pdb_in.map { metaLigands(it) },
        ligands_pdb_in.map { it.ligands_pdb_csv },
        params.prepare_chunk_size,
    )
    def ligands_pdb_chunks = RUN_SPLIT_CSV.out
        .map { meta, files ->
            [meta.key(), [ligands_pdb_csv_chunks: ensureList(files)]]
        }
        .join(
            ligands_pdb_in.map { [metaLigands(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // ligands_pdb_chunks.map { it }.dump(tag: "PREPARE_LIGAND_CHUNKS ligands_pdb_chunks", pretty: true)

    def ligands_pdb_chunks_in = ligands_pdb_chunks
        .map { [metaLigands(it), it.ligands_pdb_csv_chunks] }
        .flatMap { meta, files ->
            files.collect { file -> [meta.key(), [chunk: getChunk(file), ligands_pdb_csv_chunk: file]] }
        }
        .combine(
            ligands_pdb_in.map { [metaLigands(it).key(), it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // ligands_pdb_chunks_in.map { it }.dump(tag: "PREPARE_LIGAND_CHUNKS ligands_pdb_chunks_in", pretty: true)

    RUN_PREPARE_LIGAND(
        ligands_pdb_chunks_in.map {
            if (!it.chunk) {
                throw new Exception("Chunk is not defined 1")
            }
            metaLigandsChunk(it)
        },
        ligands_pdb_chunks_in.map { [it.ligands_pdb_csv_chunk, it.ligands_pdb_path] },
        ligands_pdb_chunks_in.map { it.iterations_path },
        ligands_pdb_chunks_in.map { it.cache_path },
    )
    def ligands_pdbqt_chunks = RUN_PREPARE_LIGAND.out
    // ligands_pdbqt_chunks.map { it }.dump(tag: "PREPARE_LIGAND_CHUNKS ligands_pdbqt_chunks", pretty: true)

    def ligands_pdbqt_merge_in = ligands_pdb_chunks
        .map { [metaLigands(it).key(), [size: it.ligands_pdb_csv_chunks.size()]] }
        .combine(
            ligands_pdbqt_chunks.map { meta, ligands_pdbqt_csv_chunk, ligands_pdbqt_path ->
                [metaLigands(meta.properties).key(), [chunk: meta.chunk, ligands_pdbqt_csv_chunk: ligands_pdbqt_csv_chunk, ligands_pdbqt_path: ligands_pdbqt_path]]
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
                chunks_ligand_pdbqt_csv: chunks*.ligands_pdbqt_csv_chunk,
                chunks_ligand_pdbqt_path: chunks*.ligands_pdbqt_path,
            ]
            return [key, chunks_it]
        }
        .join(ligands_pdb_in.map { [metaLigands(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }
    // ligands_pdbqt_merge_in.dump(tag: "PREPARE_LIGAND_CHUNKS ligands_pdbqt_merge_in", pretty: true)

    RUN_MERGE_CSV(
        ligands_pdbqt_merge_in.map { metaLigands(it) },
        ligands_pdbqt_merge_in.map { it.chunks_ligand_pdbqt_csv.sort(false) { it.getFileName().toString() } },
        ligands_pdbqt_merge_in.map { it.chunks_ligand_pdbqt_path.sort(false) { it.getFileName().toString() } },
        ligands_pdbqt_merge_in.map { it.iterations_path },
        ligands_pdbqt_merge_in.map { suffixFilename(it.ligands_pdb_csv, ".pdbqt") },
    )
    res_ligands_pdbqt = RUN_MERGE_CSV.out
        .map { meta, ligands_pdbqt_csv, ligands_pdbqt_path ->
            [meta.key(), [ligands_pdbqt_csv: ligands_pdbqt_csv, ligands_pdbqt_path: ensureList(ligands_pdbqt_path)]]
        }
        .join(ligands_pdb_in.map { [metaLigands(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }

    emit:
    ligands_pdbqt = res_ligands_pdbqt
}
