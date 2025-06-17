include { isNoFile  } from '../../../libs/utils'

process RUN_DEPLOY_CACHE {
    tag "${cache_zip ? cache_zip.getName() : 'NO CACHE ZIP'}"
    label "process_file"

    publishDir '', enabled: false

    input:
    file cache_zip
    val cache_path
    val outdir

    output:
    val "${cache_path ?: (!isNoFile(cache_zip) ? "${outdir}/cache" : null)}"

    script:
    def script = ''

    // println("######## RUN_DEPLOY_CACHE, cache_zip: ${cache_zip}")
    // println("######## RUN_DEPLOY_CACHE, cache_path: ${cache_path}")

    if (!isNoFile(cache_zip)) {
        def cache_path_val = cache_path ?: "${outdir}/cache"

        // println("######## RUN_DEPLOY_CACHE, cache_path_val: ${cache_path_val}")
        script = """
        mkdir -p "${cache_path_val}"
        unzip -uo "${cache_zip}" -d "${cache_path_val}"
        """
    } else {
        script = """
        echo "No cache .zip provided, skipping cache deployment."
        """
    }

    return script
}
