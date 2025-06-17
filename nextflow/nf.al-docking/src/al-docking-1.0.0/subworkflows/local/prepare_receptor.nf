include { RUN_PREPARE_RECEPTOR } from '../../modules/local/prepare_receptor'

workflow PREPARE_RECEPTOR {
    take:
    receptor

    main:
    RUN_PREPARE_RECEPTOR(
        receptor.map { [id: it.id] },
        receptor.map { it.receptor_pdb },
    )
    res_receptor_ch = RUN_PREPARE_RECEPTOR.out
        .map { meta, receptor_pdbqt -> [meta.id, [receptor_pdbqt: receptor_pdbqt]] }
        .join(receptor.map { it -> [it.id, it] }, by: 0)
        .map { it[2] + it[1] }

    emit:
    receptor_ch = res_receptor_ch
}
