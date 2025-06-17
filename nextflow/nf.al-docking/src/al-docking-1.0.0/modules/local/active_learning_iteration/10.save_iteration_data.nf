include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'

process RUN_SAVE_ITERATION_DATA {
    tag "${iterTag([id: idata.id], idata.iteration_num)}"
    label "process_file"

    publishDir "${iterPublishDir(idata.iterations_path, [id: idata.id], idata.iteration_num)}", mode: 'link'

    input:
    val idata

    output:
    file "${iterTag([id: idata.id], idata.iteration_num)}.iteration.json"

    script:
    """
    echo "${idata.toJsonString()} > ${iterTag([id: idata.id], idata.iteration_num)}.iteration.json"
    """
}
