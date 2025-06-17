
include { toShList                  } from '../prepare_utils.nf'
include { create_symlink_tree_shsub } from '../prepare_utils.nf'

/*
 * Run RoseTTAFold_All_Atom
 */
process RUN_ROSETTAFOLD_ALL_ATOM {
    tag "${meta.id}"
    label 'process_high'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("Local RUN_ROSETTAFOLD_ALL_ATOM module does not support Conda. Please use Docker / Singularity / Podman instead.")
    }

    container "nf-core/proteinfold_rosettafold_all_atom:dev"

    input:
    tuple val(meta), path(fasta)
    val rosettafold_all_atom_db_workdir

    output:
    tuple val(meta), path ("${meta.id}_rosettafold_all_atom.pdb"), emit: pdb
    tuple val(meta), path ("*_mqc.tsv")                          , emit: multiqc
    path "versions.yml"                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = '1.2.0dev' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    task_workdir="\$PWD"
    app_workdir="\$task_workdir/RoseTTAFold-All-Atom"

    ${create_symlink_tree_shsub()}
    create_symlink_tree "/app/RoseTTAFold-All-Atom" "\$app_workdir"
    find . -type l -name "*.sh" -exec chmod +x {} \\;

    ln -s $rosettafold_all_atom_db_workdir/uniref30/UniRef30_2020_06 \$app_workdir/UniRef30_2020_06
    ln -s $rosettafold_all_atom_db_workdir/bfd \$app_workdir/bfd
    
    cd \$app_workdir
    mamba run --name RFAA python -m rf2aa.run_inference \\
        --config-name "protein" --config-dir "\$app_workdir/rf2aa/config/inference" \\
        job_name="${meta.id}" protein_inputs.A.fasta_file="\$task_workdir/$fasta" output_path="\$task_workdir" \\
        database_params.hhdb="$rosettafold_all_atom_db_workdir/pdb100_2021Mar03/pdb100_2021Mar03" \\
        database_params.num_cpus=${task.cpus} \\
        checkpoint_path="$rosettafold_all_atom_db_workdir/params/RFAA_paper_weights.pt" \\
        $args
    cd \$task_workdir
    rm -rf \$app_workdir
    
    cp "\$task_workdir/${meta.id}".pdb ./"${meta.id}"_rosettafold_all_atom.pdb
    awk '{printf "%s\\t%.0f\\n", \$6, \$11 * 100}' "${meta.id}"_rosettafold_all_atom.pdb | uniq > plddt.tsv
    echo -e Positions"\\t""${meta.id}"_rosettafold_all_atom.pdb > header.tsv
    cat header.tsv plddt.tsv > "${meta.id}"_plddt_mqc.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    sleep 2
    touch ./"${meta.id}"_rosettafold_all_atom.pdb
    touch ./"${meta.id}"_plddt_mqc.tsv
    touch ./"${meta.id}"_aux.pt
    touch ./"${meta.id}".pdb
    touch ./header.tsv
    touch ./plddt.tsv
    mkdir ./outputs
    mkdir ./"${meta.id}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
