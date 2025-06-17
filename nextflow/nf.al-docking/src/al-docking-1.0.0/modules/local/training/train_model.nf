include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'
include { isNoFile           } from '../../../libs/utils'


process RUN_TRAIN_MODEL {
    tag "${iterTag(meta)}"
    label "process_medium"
    container "al-docking:1.0.0"

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'link'

    input:
    val meta
    path input_model_pth
    path train_csv
    path test_csv
    val iterations_path
    val cache_path

    output:
    tuple val(meta), file("${iterTag(meta)}.model.pth")

    script:
    def seed = params.random_seed
    def batch_size = params.train_batch_size
    def num_epochs = params.train_num_epochs

    def output_fn = "${iterTag(meta)}.model.pth"
    def pre_script = """
    cmd_output_fn="${output_fn}"
    """
    def post_script = ""
    def cmd_args = ''

    def cache_path_val = null // cache_path // null
    if (cache_path_val) {
        def model_cache_path = "${cache_path_val}/model-pth/${meta.id}-${meta.receptor_hash}"
        pre_script = """
        mkdir -p "${model_cache_path}"
        train_hash=\$(sha256sum "${train_csv}" | awk '{print substr(\$1,1,8)}')
        test_hash=\$(sha256sum "${test_csv}" | awk '{print substr(\$1,1,8)}')
        cmd_output_fn="${model_cache_path}/model.${meta.id}-${meta.receptor_hash}.\${train_hash}-\${test_hash}.b${batch_size}-e${num_epochs}-s${seed}.pth"
        echo "cmd_output_fn: \${cmd_output_fn}"
        """

        post_script = """
        ln -s "\${cmd_output_fn}" "${output_fn}"
        """
    }

    def input_args = ''
    if (!isNoFile(input_model_pth)) {
        input_args = "--input \"${input_model_pth}\" "
    }
    def script = """
    if [[ ! -f "\${cmd_output_fn}" ]]; then
        conda run -n activelearning train_map \\
            --title            "${meta.id}" \\
            --train            "${train_csv}" \\
            --test             "${test_csv}" \\
            --target_col       "affinity" \\
            --smiles_col       "${params.compound_smiles_col}" \\
            --seed             ${seed} \\
            --batch_size       ${batch_size} \\
            --num_epoches      ${num_epochs} \\
            --use_gpu          ${params.use_gpu ? 'on': 'off'} \\
            --model_type       "${params.model_type}" \\
            --num_layers       ${params.model_num_layers} \\
            --hidden_dim       ${params.model_hidden_dim} \\
            --out_dim          ${params.model_out_dim} \\
            --readout          ${params.model_readout_method} \\
            --multiply_num_pma ${params.model_multiply_num_pma} \\
            --dropout_prob     ${params.model_dropout_prob} \\
            ${input_args} \\
            --output           "\${cmd_output_fn}" \\
            ${cmd_args}
    fi
    """
    return pre_script + script + post_script
}
