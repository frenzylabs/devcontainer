
push:
	$(eval LAST_COMMIT=$(shell git --git-dir=./.git rev-parse --short HEAD))
	docker tag frenzylab/devcontainer:latest frenzylab/devcontainer:${LAST_COMMIT}
	docker push frenzylab/devcontainer:${LAST_COMMIT}