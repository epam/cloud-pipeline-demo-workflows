include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { iterationFilesPath } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'
include { isNoFile           } from '../../../libs/utils'

process RUN_PREPARE_LIGAND {
    tag "${iterTag(meta)}-${meta.role}${meta.hasProperty('chunk') ? "#${meta.chunk}" : ""}"
    label "process_single"
    container "al-docking:1.0.0"

    publishDir '', enabled: false

    input:
    val meta
    tuple file(ligands_pdb_csv), path(ligands_pdb_path)
    val iterations_path
    val cache_path

    output:
    tuple val(meta), file("${suffixFilename(ligands_pdb_csv, ".pdbqt")}"), path("${iterationFilesPath("ligand-pdbqt-", meta)}")

    script:
    // println("######## RUN_PREPARE_LIGAND")
    def output_fn = "${suffixFilename(ligands_pdb_csv, ".pdbqt")}"
    def script = ''

    def pre_script = """
    iteration_num=${meta.iteration_num}
    pdbqt_path="${iterationFilesPath("ligand-pdbqt-", meta)}"
    mkdir -p "\$pdbqt_path"
    """

    if (isNoFile(ligands_pdb_csv)) {
        script = """
        touch "${output_fn}"
        """
    }
    else {
        def cmd_args = ''
        def cache_path_val = cache_path
        if (cache_path_val) {
            def pdbqt_cache_path = "${cache_path_val}/ligand-pdbqt"
            pre_script += """
            mkdir -p ${pdbqt_cache_path}
            """
            cmd_args = "--cache ${pdbqt_cache_path}"
        }
        script = """
        conda run -n base batch_prepare_ligand.py \\
            --input "${ligands_pdb_csv}" \\
            --input-id-col "${params.compound_id_col}" \\
            --input-pdb-col "${params.compound_pdb_col}" \\
            --output "${output_fn}" \\
            --output-pdbqt-col "${params.compound_pdbqt_col}" \\
            --output-pdbqt-pattern "\$pdbqt_path/ligand.{ID}.pdbqt" \\
            ${cmd_args} # --cache
        """
    }
    return pre_script + script
}
