process RUN_GENERATE_REPORT {
    tag "${meta.id}"
    label 'process_single'
    container "al-docking:1.0.0"

    publishDir "${params.outdir}/reports", mode: 'copy', overwrite: true

    input:
    val meta
    path iterations_path
    path params_json
    path report_template

    output:
    tuple val(meta), path("report.${meta.id}.html")

    script:
    """
    conda run -n activelearning generate_report.py \\
        --template      "${report_template}" \\
        --data-dir      "${iterations_path}" \\
        --receptor      "${meta.id}" \\
        --params-json   "${params_json}" \\
        --figures-dir   "${params.outdir}/figures" \\
        --output        "report.${meta.id}.html"
    """
}
