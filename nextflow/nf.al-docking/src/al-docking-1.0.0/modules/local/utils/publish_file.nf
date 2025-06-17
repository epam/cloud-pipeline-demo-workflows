include { iterTag        } from '../../../libs/utils'
include { iterPublishDir } from '../../../libs/utils'

process RUN_PUBLISH_FILE {
    tag "${target.getName()}"
    label 'process_file'

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'copy'

    input:
    val meta
    file target
    val iterations_path

    output:
    tuple val(meta), path("${target.getName()}")

    script:
    """
    echo Publish file: ${target}
    """
}
