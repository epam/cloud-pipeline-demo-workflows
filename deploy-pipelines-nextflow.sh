#!/usr/bin/env bash

pipeline_dirs=(
  "nextflow/nf.al-docking"
  "nextflow/nf-core.methylseq" 
  "nextflow/nf-core.proteinfold" 
  "nextflow/nf-core.rnaseq" 
  "nextflow/nf-core.sarek"
  "nextflow/nf-core.scrnaseq"
)
env_file=".env"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_prerequisites() {
    res=1
    if ! command -v "jq" > /dev/null 2>&1; then
        echo "ERROR: 'jq' is required but not installed." >&2
        echo "Install it (e.g. sudo apt-get update && sudo apt-get install -y jq )" >&2
        res=0
    fi
    if ! command -v "envsubst" > /dev/null 2>&1; then
        echo "ERROR: 'envsubst' is required but not installed. " >&2
        echo "Please install it (e.g. sudo apt-get update && sudo apt-get install -y gettext)" >&2
        res=0
    fi
    if [ "$res" = "0" ]; then
        echo "Please install the required prerequisites and try again." >&2
        exit 1
    fi
}

load_env() {
    local ENV_FILE="$SCRIPT_DIR/$env_file"
    if [ -f "$ENV_FILE" ]; then
        set -o allexport
        source "$ENV_FILE"
        set +o allexport
    else
        echo "ERROR: .env-aws file not found in $SCRIPT_DIR"
        echo "Please create .env-aws with the following content:"
        cat << 'EOF'
CP_CODE_BASE=<cloud_pipeline_code_base_path>
CP_API_JWT_ADMIN=<your_jwt_token_here>
CP_API_SRV_INTERNAL_HOST=<cloud_pipeline_host>
CP_API_SRV_INTERNAL_PORT=<443>
GITLAB_ROOT_USER=<user_name>
GITLAB_ROOT_PASSWORD=<your_gitlab_user_password>
CP_GITLAB_INTERNAL_HOST=<git_host>
CP_GITLAB_INTERNAL_PORT=<443>
CP_CLOUD_PLATFORM=<aws|gcp>
NF_DEMO_BUCKET=<gs|s3://nf-core-demo-data-bucket>
EOF
      exit 1
    fi
}

prepare_temp_dir() {
    local temp_dir=$(mktemp -d)
    echo "Created temp dir: $temp_dir" >&2

    for dir in "${pipeline_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Copying \"$dir\" to temporary directory..." >&2
            cp -r "$dir" "$temp_dir/"
        else
            echo "Warning: Directory \"$dir\" not found, skipping..." >&2
        fi
    done

    cd "$temp_dir"
    echo "$temp_dir"
}

load_env
echo "CP_ROOT: $CP_ROOT"
source "$CP_ROOT/deploy/contents/install/app/configure-utils.sh"
source "$CP_ROOT/deploy/contents/install/app/format-utils.sh"
source "$CP_ROOT/deploy/contents/install/app/install-utils.sh"
# CP_DOLLAR='$'

check_prerequisites
TEMP_DIR=$(prepare_temp_dir)
trap 'rm -rf "$TEMP_DIR"' EXIT

api_register_demo_pipelines "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "ERROR"; exit 1
else
    echo "OK"
fi