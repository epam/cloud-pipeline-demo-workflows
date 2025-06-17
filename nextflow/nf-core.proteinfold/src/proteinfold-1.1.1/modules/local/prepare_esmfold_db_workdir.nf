
include { toShList                  } from './prepare_utils.nf'
include { create_workdir_sh         } from './prepare_utils.nf'
include { create_symlink_list_shsub } from './prepare_utils.nf'

process PREPARE_ESMFOLD_DB_WORKDIR {
    label 'process_single'

    input:
    val esmfold_db_workdir
    val params_path

    output:
    val esmfold_db_workdir

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    params_path_list=${toShList(params_path)}
    ${create_symlink_list_shsub() }
    ${create_workdir_sh(esmfold_db_workdir)}
    work="$esmfold_db_workdir"
    create_symlink_list params_path_list "\$work"
    echo "Complete esmfold_db workdir to '\$work'"

    """

    stub:
    """
    work="$esmfold_db_workdir"
    mkdir -p \$work
    """
}