include { RUN_DOCKING_QVINA } from '../../modules/local/docking/04.docking_qvina'
include { metaLigands       } from '../../libs/meta'

workflow DOCKING_QVINA {
    take:
    ligands_pdbqt

    main:
    def ligands_pdbqt_in = ligands_pdbqt
    // ligands_pdbqt_in.dump(tag: "DOCKING_QVINA ligands_pdbqt_in", pretty: true)

    RUN_DOCKING_QVINA(
        ligands_pdbqt.map { metaLigands(it) },
        ligands_pdbqt.map { [it.ligands_pdbqt_csv, it.ligands_pdbqt_path] },
        ligands_pdbqt.map { [it.receptor_pdbqt, it.receptor_pocket_config] },
        ligands_pdbqt.map { it.iterations_path },
        ligands_pdbqt.map { it.cache_path },
    )

    def res_ligands_docked = RUN_DOCKING_QVINA.out
        .map { meta, docked_csv, docked_path ->
            [meta.id, meta.role, [ligands_docked_csv: docked_csv, ligands_docked_path: docked_path]]
        }
        .join(ligands_pdbqt.map { [it.id, it.role, it] }, by: [0, 1])
        .map { it[3] + it[2] }
    // res_ligands_docked.dump(tag: "DOCKING_QVINA res_ligands_docked", pretty: true)

    emit:
    ligands_docked = res_ligands_docked
}
