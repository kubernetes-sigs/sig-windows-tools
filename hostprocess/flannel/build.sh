docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT
docker buildx build --platform windows/amd64 --output=type=registry --pull -f Dockerfile -t jsturtevant/flannel:hostprocess .