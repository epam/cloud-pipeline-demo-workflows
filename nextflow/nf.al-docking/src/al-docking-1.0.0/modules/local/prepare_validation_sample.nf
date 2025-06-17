include { iterToStr      } from '../../libs/utils'
include { iterPublishDir } from '../../libs/utils'
include { iterTag        } from '../../libs/utils'


process RUN_PREPARE_VALIDATION_SAMPLE {
    tag "${meta.id}"
    label 'process_file'

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'link'

    input:
    val meta
    val iterations_path
    file compound_db_csv
    val validation_sample_size

    output:
    tuple val(meta), file("validation-${meta.id}.csv"), file("unlabeled-${meta.id}.csv")

    script:
    def args = ''
    if (params.random_seed != null) {
        args = "--seed ${params.random_seed}"
    }
    """
    conda run -n base split_csv.py \\
        --input       "${compound_db_csv}" \\
        --part        "validation-${meta.id}.csv" \\
        --part-size   ${validation_sample_size} \\
        --remain      "unlabeled-${meta.id}.csv" \\
        ${args}    
    """
}
