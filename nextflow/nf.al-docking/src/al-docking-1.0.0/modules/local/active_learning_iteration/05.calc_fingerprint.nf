include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'
include { getAbsolutePath    } from '../../../libs/utils'
include { isNoFile           } from '../../../libs/utils'

process RUN_CALC_FINGERPRINT {
    tag "${iterTag(meta, iteration_num)}-${meta.role}"
    label "process_single"
    container "al-docking:1.0.0"

    publishDir "${iterPublishDir(iterations_path, meta, iteration_num)}", mode: 'link'

    input:
    tuple val(meta), val(iteration_num), path(ligands_csv)
    val iterations_path
    val cache_path

    output:
    tuple val(meta), path("${suffixFilename(ligands_csv, ".fp")}")

    script:
    def output_fn = "${suffixFilename(ligands_csv, ".fp")}"
    def script = ''
    def pre_script = ''

    if (isNoFile(ligands_csv)) {
        script = """
        touch "${output_fn}"
        """
    }
    else {
        def cmd_args = ''
        def cache_path_val = cache_path
        script = """
        conda run -n rdkit batch_calc_fingerprints.py \\
            --input "${ligands_csv}" \\
            --input-id-col "${params.compound_id_col}" \\
            --input-smiles-col "${params.compound_smiles_col}" \\
            --ecfp-radius "${params.ecfp_radius}" \\
            --ecfp-nbits "${params.ecfp_nbits}" \\
            --output "${output_fn}" \\
            ${cmd_args} # --cache
        """
    }
    return pre_script + script
}
