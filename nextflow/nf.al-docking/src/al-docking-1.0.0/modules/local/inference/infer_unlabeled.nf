include { iterToStr      } from '../../../libs/utils'
include { iterPublishDir } from '../../../libs/utils'
include { iterTag        } from '../../../libs/utils'
include { suffixFilename } from '../../../libs/utils'
include { isNoFile       } from '../../../libs/utils'


process RUN_INFER_UNLABELED {
    tag "${iterTag(meta)}${meta.hasProperty('chunk') ? "#${meta.chunk}" : ""}"
    label "process_medium"
    container "al-docking:1.0.0"

    publishDir '', enabled: false

    input:
    tuple val(meta), val(suffix)
    path unlabeled_csv
    path model_pth
    val iterations_path
    val cache_path

    output:
    tuple val(meta), file("${suffixFilename(unlabeled_csv, suffix ?: ".inferred")}")

    script:
    def seed = params.random_seed

    def output_fn = "${suffixFilename(unlabeled_csv, suffix ?: ".inferred")}"
    def unlabeled_base = unlabeled_csv.getBaseName()
    // println("######## RUN_INFER_UNLABELED: output_fn: ${output_fn}, unlabeled_base: ${unlabeled_base}")

    def pre_script = """
    iteration_num=${meta.iteration_num}
    cmd_output_fn="${output_fn}"
    """
    def post_script = ""

    def script = ''
    if (isNoFile(unlabeled_csv) || isNoFile(model_pth)) {
        script = """
        touch "\${cmd_output_fn}"
        """
    }
    else {
        // def cmd_args = ''

        def cache_path_val = null // cache_path // null
        if (cache_path_val) {
            def inferred_cache_path = "${cache_path_val}/inferred-csv/${meta.id}-${meta.receptor_hash}"
            pre_script = """
            mkdir -p "${inferred_cache_path}"
            unlabeled_hash=\$(sha256sum "${unlabeled_csv}" | awk '{print substr(\$1,1,6)}')
            model_hash=\$(sha256sum "${model_pth}" | awk '{print substr(\$1,1,6)}')
            
            cmd_output_fn="${inferred_cache_path}/${unlabeled_base}-\${unlabeled_hash}.inferred-\${model_hash}.csv"

            echo "cmd_output_fn: \${cmd_output_fn}"
            """

            post_script = """
            ln -s "\${cmd_output_fn}" "${output_fn}"
            """
        }

        script = """
        if [[ ! -f "\${cmd_output_fn}" ]]; then
            conda run -n activelearning inference_map \\
                --title            "${meta.id}" \\
                --use_gpu          ${params.use_gpu ? 'on' : 'off'} \\
                --unlabeled        "${unlabeled_csv}" \\
                --model_type       "${params.model_type}" \\
                --num_layers       ${params.model_num_layers} \\
                --hidden_dim       ${params.model_hidden_dim} \\
                --out_dim          ${params.model_out_dim} \\
                --readout          ${params.model_readout_method} \\
                --multiply_num_pma ${params.model_multiply_num_pma} \\
                --dropout_prob     ${params.model_dropout_prob} \\
                --model            "${model_pth}" \\
                --batch_size       ${params.inference_batch_size} \\
                --seed             ${seed} \\
                --output           "\${cmd_output_fn}"
        fi
        """
    }
    return pre_script + script + post_script
}
