process RUN_HARVEST_CACHE {
    label "process_file"

    publishDir "cache-out.zip"

    input:
    val iters
    val cache_path
    val outdir

    output:
    val "cache-out.zip"

    script:
    def script = ''

    // println("######## RUN_HARVEST_CACHE, cache_path: ${cache_path}")
    // println("######## RUN_HARVEST_CACHE, outdir: ${outdir}")

    if (cache_path) {
        script = """
        current_dir=\$(pwd)
        cd "${cache_path}"
        zip -r "${outdir}/cache-out.zip" .
        cd "\${current_dir}"
        """
    }

    return script
}
