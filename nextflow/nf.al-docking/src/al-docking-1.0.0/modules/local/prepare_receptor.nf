process RUN_PREPARE_RECEPTOR {
    tag "${meta.id}"
    label 'process_single'
    container "al-docking:1.0.0"

    publishDir "${params.outdir}/prepared_receptors", mode: 'copy', overwrite: true

    input:
    val(meta)
    path(receptor_pdb)

    output:
    tuple val(meta), path("receptor.${meta.id}.pdbqt")

    script:
    def out_dir = "${params.outdir}/prepared_receptors"
    """
    mkdir -p "${out_dir}"
    echo "Preparing receptor: ${receptor_pdb}"
    conda run -n mgltools prepare_receptor4.py \
        -r "${receptor_pdb}" \
        -o "receptor.${meta.id}.pdbqt"
    """
}
