docker buildx create --name bitcoin-builder --node bitcoin-builder-node --platform linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6 --config buildkitd.toml --driver docker-container
docker buildx inspect --builder bitcoin-builder --bootstrap
docker update buildx_buildkit_bitcoin-builder-node --restart=always
