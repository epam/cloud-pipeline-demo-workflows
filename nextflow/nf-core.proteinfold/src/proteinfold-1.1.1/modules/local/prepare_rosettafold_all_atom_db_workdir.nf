
include { toShList                  } from './prepare_utils.nf'
include { create_workdir_sh         } from './prepare_utils.nf'
include { create_symlink_list_shsub } from './prepare_utils.nf'
include { create_symlink_file_shsub } from './prepare_utils.nf'

process PREPARE_ROSETTAFOLD_ALL_ATOM_DB_WORKDIR {
    label 'process_single'

    input:
    val rosettafold_all_atom_db_workdir
    val bfd_path
    val uniref30_path
    val pdb100_path
    val params_path

    output:
    val rosettafold_all_atom_db_workdir

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    bfd_path_list=${toShList(bfd_path)}
    uniref30_path_list=${toShList(uniref30_path)}
    pdb100_path_list=${toShList(pdb100_path)}
    params_path_list=${toShList(params_path)}

    ${create_symlink_list_shsub() }
    ${create_symlink_file_shsub() }
    ${create_workdir_sh(rosettafold_all_atom_db_workdir)}

    work="$rosettafold_all_atom_db_workdir"
    create_symlink_list bfd_path_list      "\$work/bfd"
    create_symlink_list uniref30_path_list "\$work/uniref30/UniRef30_2020_06"
    create_symlink_list pdb100_path_list   "\$work/pdb100_2021Mar03"
    create_symlink_list params_path_list   "\$work/params"

    """

    stub:
    """
    work="$rosettafold_all_atom_db_workdir"
    mkdir -p \$work
    """
}