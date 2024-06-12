
# Make new builder in order to build for multiple platforms at once
# docker builder create --use

build: 
	docker buildx build --platform=linux/amd64,linux/arm64 -t frenzylab/devcontainer:bullseye11 --push . 

push:
	$(eval LAST_COMMIT=$(shell git --git-dir=./.git rev-parse --short HEAD))
	docker tag frenzylab/devcontainer:latest frenzylab/devcontainer:${LAST_COMMIT}
	docker push frenzylab/devcontainer:${LAST_COMMIT}