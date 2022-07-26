DOCKER_NAME = infra/bmc-sol-collector
DOCKER_TAG ?= 0.4.0
PUSH_TAG ?= $(DOCKER_TAG)
REGISTRY ?= prt-registry.sova.intel.com
ROOT_DIR ?= $(shell git rev-parse --show-toplevel)

docker-build:
	docker build $(BUILD_ARGS) . -t $(DOCKER_NAME):$(DOCKER_TAG)

docker-test: docker-build
	docker run --rm  --net=host $(DOCKER_NAME):$(DOCKER_TAG) $(TEST_ARGS)

docker-push: docker-build
	docker tag $(DOCKER_NAME):$(DOCKER_TAG) $(REGISTRY)/$(DOCKER_NAME):$(DOCKER_TAG)
	docker push $(REGISTRY)/$(DOCKER_NAME):$(DOCKER_TAG)
