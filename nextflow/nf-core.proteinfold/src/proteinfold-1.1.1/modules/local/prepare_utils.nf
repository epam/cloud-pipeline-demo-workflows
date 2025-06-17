
def ensureList(obj) {
    return obj instanceof List ? obj : [obj];
}

def toShList(obj) {
    return '(' + ensureList(obj).collect { "\"${it}\""}.join(' ') + ')'
}

def create_workdir_sh(work) {
    return """
    work="${work}"
    if [[ -e \$work ]]; then
        echo "Path '\$work' exists already" >&2
        exit 1
    else
        mkdir -p "\$work"
    fi    
"""
}

def create_symlink_tree_shsub() {
    return """
    create_symlink_tree() {
        local src=\$1
        local dst=\$2

        mkdir -p \$dst
        find \$src -type d -printf '%P\\n' | xargs -I {} mkdir -p \$dst/{}
        find \$src -type f -printf '%P\\n' | xargs -I {} ln -s \$src/{} \$dst/{}
    }
    """
}

def create_symlink_list_shsub() {
    return """
    create_symlink_list() {
        local -n path_list=\$1
        local work_dir=\$2

        mkdir -p \$work_dir
        for file in \${path_list[@]}; do
            ln -s \$file \$work_dir/\$(basename \$file)
        done
    }
"""
}

def create_symlink_file_shsub() {
    return """
    create_symlink_file() {
        local src=\$1
        local dst=\$2
        ln -s \$src \$dst
    }
"""
}
