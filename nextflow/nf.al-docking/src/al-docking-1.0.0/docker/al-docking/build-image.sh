# registry="docker.dev.gcp.cloud-pipeline.com:443/library/"
registry="docker.aws.cloud-pipeline.com:443/library/"
image="al-docking:1.0.0"

pushd . > /dev/null
trap 'popd > /dev/null' EXIT

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

docker build -f "$SCRIPT_DIR/Dockerfile" -t ${docker_repository_prefix}${image} . || exit 1

if [ -n "${registry}" ]; then
    echo "Docker: ${registry}"
    docker tag ${image} ${registry}${image} && \
    docker push ${registry}${image}
fi

echo OK