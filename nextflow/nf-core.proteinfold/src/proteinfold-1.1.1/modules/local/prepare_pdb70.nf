
process PREPARE_PDB70 {
    label 'process_single'
    publishDir 'pdb70', saveAs: { null } // mode: 'off' is not available

    input:
        val pdb70_path
    
    output:
        path 'pdb70'

    script:
    """
    pdb70_path=${pdb70_path}
    mkdir pdb70
    find \$pdb70_path -type d -printf '%P\\n' | xargs -I {} mkdir -p pdb70/{}
    find \$pdb70_path -type f -printf '%P\\n' | xargs -I {} ln -s \$pdb70_path/{} pdb70/{}
    echo "Completed"
    """

    stub:
    """
    pdb70_path=${pdb70_path}
    mkdir pdb70
    find \$pdb70_path -type d -printf '%P\\n' | xargs -I {} mkdir -p pdb70/{}
    find \$pdb70_path -type f -printf '%P\\n' | xargs -I {} ln -s \$pdb70_path/{} pdb70/{}
    echo "Completed"
    """
}