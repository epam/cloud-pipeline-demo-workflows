include { RUN_PREPARE_LIGAND } from '../../modules/local/docking/03.prepare_ligand'
include { metaLigands } from '../../libs/meta'

workflow PREPARE_LIGAND {
    take:
    ligands_pdb

    main:
    def ligands_pdb_in = ligands_pdb
    // ligands_pdb_in.dump(tag: "PREPARE_LIGAND ligands_pdb_in", pretty: true)

    RUN_PREPARE_LIGAND(
        ligands_pdb_in.map { metaLigands(it) },
        ligands_pdb_in.map { [it.ligands_pdb_csv, it.ligands_pdb_path] },
        ligands_pdb_in.map { it.iterations_path },
        ligands_pdb_in.map { it.cache_path },
    )
    def res_ligands_pdbqt = RUN_PREPARE_LIGAND.out
        .map { meta, ligands_pdbqt_csv, ligands_pdbqt_path ->
            [meta.id, meta.role, [ligands_pdbqt_csv: ligands_pdbqt_csv, ligands_pdbqt_path: ligands_pdbqt_path]]
        }
        .join(ligands_pdb.map { [it.id, it.role, it] }, by: [0, 1])
        .map { it[3] + it[2] }
    // res_ligands_pdbqt.dump(tag: "PREPARE_LIGAND res_ligands_pdbqt", pretty: true)

    emit:
    ligands_pdbqt = res_ligands_pdbqt
}
