include { iterToStr      } from '../../../libs/utils'
include { iterPublishDir } from '../../../libs/utils'
include { iterTag        } from '../../../libs/utils'
include { isNoFile       } from '../../../libs/utils'

process RUN_SPLIT_TRAINING_SAMPLE {
    tag "${iterTag(meta)}"
    label "process_file"
    container "al-docking:1.0.0"

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'link'

    input:
    val meta
    tuple path(unlabeled_csv), path(inferred_csv)
    val iterations_path

    output:
    tuple val(meta), path("${iterTag(meta)}.train.csv"), path("${iterTag(meta)}.test.csv"), path("${iterTag(meta)}.unlabeled.csv")

    script:
    def train_csv = "${iterTag(meta)}.train.csv"
    def test_csv = "${iterTag(meta)}.test.csv"
    def remain_csv = "${iterTag(meta)}.unlabeled.csv" 

    def train_remain_csv = "${iterTag(meta)}.train_remain.csv"
    def pre_script = """
    iteration_num=${meta.iteration_num}
    """
    def script = ''
    if (!isNoFile(inferred_csv)) {
        // Active learning strategy method
        def cmd_args = ''
        if (params.random_seed != null) {
            cmd_args += "--seed ${params.random_seed}"
        }
        script = """
        conda run -n activelearning edit_dataset \\
            --title       "${meta.id}" \\
            --input       "${inferred_csv}" \\
            --method      "${params.active_learning_method}" \\
            --output_size ${params.train_sample_size} \\
            --output      "${train_csv}" \\
            --remain      "${train_remain_csv}" \\
            ${cmd_args}
        """
    } else if (!isNoFile(unlabeled_csv)) {
        // Random
        def cmd_args = ''
        if (params.random_seed != null) {
            cmd_args += "--seed ${params.random_seed}"
        }
        script = """
        conda run -n base split_csv.py \\
            --input       "${unlabeled_csv}" \\
            --part        "${train_csv}" \\
            --part-size   ${params.train_sample_size} \\
            --remain      ${train_remain_csv}\\
            ${cmd_args}
        """
    } else {
        throw new Exception("No unlabeled or inferred csv file found")
    }

    def cmd_args = ''
    if (params.random_seed != null) {
        cmd_args += "--seed ${params.random_seed}"
    }
    script += """
    conda run -n base split_csv.py \\
        --input       "${train_remain_csv}" \\
        --part        "${test_csv}" \\
        --part-size   ${params.test_sample_size} \\
        --remain      "${remain_csv}" \\
        ${cmd_args}
    """

    def post_script = """
    rm "${train_remain_csv}"
    """

    return pre_script + script + post_script
}
