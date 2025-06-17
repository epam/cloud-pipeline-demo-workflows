include { iterToStr          } from '../../../libs/utils'
include { iterPublishDir     } from '../../../libs/utils'
include { iterTag            } from '../../../libs/utils'
include { iterationFilesPath } from '../../../libs/utils'
include { suffixFilename     } from '../../../libs/utils'
include { isNoFile           } from '../../../libs/utils'


process RUN_SMILES_TO_PDB {
    tag "${iterTag(meta)}-${meta.role}"
    label "process_single"
    container "al-docking:1.0.0"

    publishDir "${iterPublishDir(iterations_path, meta)}", mode: 'link'

    input:
    val meta
    path ligands_csv
    val iterations_path
    val cache_path

    output:
    tuple val(meta), file("${suffixFilename(ligands_csv, ".pdb")}"), path("${iterationFilesPath("ligand-pdb-", meta)}")

    script:
    def output_fn = "${suffixFilename(ligands_csv, ".pdb")}"
    def script = ''

    def pre_script = """
    iteration_num=${meta.iteration_num}
    pdb_path="${iterationFilesPath("ligand-pdb-", meta)}"
    mkdir -p "\$pdb_path"
    """

    if (isNoFile(ligands_csv)) {
        script = """
        touch "${output_fn}"
        """
    }
    else {
        def cmd_args = ''
        def cache_path_val = cache_path
        if (cache_path_val) {
            def pdb_cache_path = "${cache_path_val}/ligand-pdb"
            pre_script += """
            mkdir -p ${pdb_cache_path}
            """
            cmd_args = "--cache ${pdb_cache_path}"
        }
        script = """
        conda run -n base batch_obabel.py \\
            --input "${ligands_csv}" \\
            --input-id-col ${params.compound_id_col} \\
            --input-smiles-col ${params.compound_smiles_col} \\
            --output "${output_fn}" \\
            --output-pdb-col PDB \\
            --output-pdb-pattern "\$pdb_path/ligand.{ID}.pdb" \\
            --gen3d -d \\
            ${cmd_args} # --cache
        """
    }
    return pre_script + script
}
