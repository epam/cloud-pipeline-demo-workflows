process RUN_PLOT_FIGURES {
    tag "${meta.id}"
    label 'process_single'
    container "al-docking:1.0.0"

    publishDir "${params.outdir}/figures", mode: 'copy', overwrite: true

    input:
    val meta
    path iterations_path
    val max_iteration_num

    output:
    tuple val(meta), path("fig*.png")

    script:
    """
    conda run -n activelearning plot_figures.py \\
        --data-dir         "${iterations_path}" \\
        --receptor         "${meta.id}" \\
        --max-iteration-num "${max_iteration_num}" \\
        --out-dir          "." 
    """
}
