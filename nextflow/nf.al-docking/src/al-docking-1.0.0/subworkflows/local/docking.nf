include { RUN_SMILES_TO_PDB     } from '../../modules/local/docking/02.smiles_to_pdb'
include { PREPARE_LIGAND        } from './prepare_ligand'
include { PREPARE_LIGAND_CHUNKS } from './prepare_ligand_chunks'
include { DOCKING_QVINA         } from './docking_qvina'
include { DOCKING_QVINA_CHUNKS  } from './docking_qvina_chunks'
include { metaLigands           } from '../../libs/meta'

workflow DOCKING {
    take:
    ligands

    main:
    def ligands_in = ligands
    // ligands_ch.dump(tag: "DOCKING ligands_ch", pretty: true)
    RUN_SMILES_TO_PDB(
        ligands_in.map { metaLigands(it) },
        ligands_in.map { it.ligands_csv },
        ligands_in.map { it.iterations_path },
        ligands_in.map { it.cache_path },
    )
    def ligands_pdb = RUN_SMILES_TO_PDB.out
        .map { meta, ligands_pdb_csv, ligands_pdb_path ->
            [meta.id, meta.role, [ligands_pdb_csv: ligands_pdb_csv, ligands_pdb_path: ligands_pdb_path]]
        }
        .join(ligands_in.map { [it.id, it.role, it] }, by: [0, 1])
        .map { it[3] + it[2] }
    // ligand_pdb.dump(tag: "DOCKING ligand_pdb", pretty: true)

    PREPARE_LIGAND_CHUNKS(ligands_pdb)
    def ligands_pdbqt = PREPARE_LIGAND_CHUNKS.out.ligands_pdbqt
    // ligands_pdbqt.dump(tag: "DOCKING ligands_pdbqt", pretty: true)

    DOCKING_QVINA_CHUNKS(ligands_pdbqt)
    ligands_docked = DOCKING_QVINA_CHUNKS.out

    res_ligands = ligands_docked

    emit:
    ligands = res_ligands
}
