include { iterTag        } from '../../../libs/utils'
include { iterPublishDir } from '../../../libs/utils'


process RUN_MERGE_CSV {
    tag "${iterTag(meta)}${meta.hasProperty('role') ? "-${meta.role}" : ""}"
    label 'process_file'

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'copy'

    input:
    val meta
    path chunks_csv
    path chunks_path
    val iterations_path
    val output

    output:
    tuple val(meta), path("${output}"), path(chunks_path)

    script:

    // print("######## RUN_MERGE_CSV, chunks_csv: ${chunks_csv}")
    // print("######## RUN_MERGE_CSV, chunks_path: ${chunks_path}")

    """
    head -n 1 \$(ls ${chunks_csv} | head -n 1) > ${output}
    tail -n +2 -q ${chunks_csv} >> ${output}
    """
}
