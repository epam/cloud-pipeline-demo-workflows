
include { toShList                  } from './prepare_utils.nf'
include { create_workdir_sh         } from './prepare_utils.nf'
include { create_symlink_list_shsub } from './prepare_utils.nf'
include { create_symlink_file_shsub } from './prepare_utils.nf'

process PREPARE_ALPHAFOLD2_DB_WORKDIR{
    label 'process_single'

    input:
    val alphafold2_db_workdir
    val params_path
    val bfd_path
    val small_bfd_path
    val mgnify_path
    val pdb70_path
    val pdb_mmcif_path
    val pdb_obsolete_path
    val uniref30_path
    val uniref90_path
    val pdb_seqres_path
    val uniprot_path

    output:
    val alphafold2_db_workdir

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    params_path_list=${toShList(params_path)}
    bfd_path_list=${toShList(bfd_path)}
    small_bfd_path_list=${toShList(small_bfd_path)}
    mgnify_path_list=${toShList(mgnify_path)}
    pdb70_path_list=${toShList(pdb70_path)}
    pdb_mmcif_path_list=${toShList(pdb_mmcif_path)}
    uniref30_path_list=${toShList(uniref30_path)}
    uniref90_path_list=${toShList(uniref90_path)}
    pdb_seqres_path_list=${toShList(pdb_seqres_path)}
    uniprot_path_list=${toShList(uniprot_path)}

    ${create_symlink_list_shsub()}
    ${create_symlink_file_shsub()}
    ${create_workdir_sh(alphafold2_db_workdir)}

    work="$alphafold2_db_workdir"

    create_symlink_list params_path_list     "\$work/params"
    create_symlink_list bfd_path_list        "\$work/bfd"
    create_symlink_list small_bfd_path_list  "\$work/small_bfd"
    create_symlink_list mgnify_path_list     "\$work/mgnify"
    create_symlink_list pdb70_path_list      "\$work/pdb70" # TODO: subdirs
    
    create_symlink_list pdb_mmcif_path_list  "\$work/pdb_mmcif" # pdb_mmcif/mmcif_files
    create_symlink_file $pdb_obsolete_path   "\$work/pdb_mmcif/obsolete.dat"
    
    create_symlink_list uniref30_path_list   "\$work/uniref30"
    create_symlink_list uniref90_path_list   "\$work/uniref90"
    create_symlink_list pdb_seqres_path_list "\$work/pdb_seqres"
    create_symlink_list uniprot_path_list    "\$work/uniprot"
    echo Completed
    """

    stub:
    """
    work="$alphafold2_db_workdir"
    mkdir -p \$work
    """
}