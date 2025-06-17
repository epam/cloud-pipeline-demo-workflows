include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { iterationFilesPath } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'
include { isNoFile           } from '../../../libs/utils'

process RUN_DOCKING_QVINA {
    tag "${iterTag(meta)}-${meta.role}${meta.hasProperty('chunk') ? "#${meta.chunk}" : ""}"
    label "process_qvina_low"
    container "al-docking:1.0.0"

    publishDir '', enabled: false

    input:
    val meta
    tuple file(ligands_pdbqt_csv), path(ligands_pdbqt_path)
    tuple file(receptor_pdbqt), file(receptor_pocket_config)
    val iterations_path
    val cache_path

    output:
    tuple val(meta), file("${suffixFilename(ligands_pdbqt_csv, ".docked")}"), path("${iterationFilesPath("poses-pdbqt-", meta)}")

    script:
    def output_fn = "${suffixFilename(ligands_pdbqt_csv, ".docked")}"

    def pre_script = """
    iteration_num=${meta.iteration_num}
    poses_path="${iterationFilesPath("poses-pdbqt-", meta)}"
    mkdir -p "\$poses_path"
    """
    if (isNoFile(ligands_pdbqt_csv)) {
        script = """
        touch "${output_fn}"
        """
    }
    else {
        def cmd_args = ''
        def cache_path_val = cache_path
        if (cache_path_val) {
            def qvina_cache_path = "${cache_path_val}/poses-pdbqt"
            pre_script += """
            mkdir -p ${qvina_cache_path}
            """
            cmd_args = " --cache \"${qvina_cache_path}\""
        }
        if (params.random_seed) {
            cmd_args += " --seed ${params.random_seed}"
        }
        def receptor_id = meta.id

        script = """
        conda run -n base batch_docking_qvina.py \\
            --cpus ${task.cpus * 3} \\
            --input "${ligands_pdbqt_csv}" \\
            --input-id-col "${params.compound_id_col}" \\
            --input-pdbqt-col "${params.compound_pdbqt_col}" \\
            --receptor-id "${receptor_id}" \\
            --receptor-pdbqt "${receptor_pdbqt}" \\
            --config ${receptor_pocket_config} \\
            --output "${output_fn}" \\
            --poses-pdbqt-dir "\$poses_path" \\
            ${cmd_args} # --cache
        """
    }
    return pre_script + script
}
