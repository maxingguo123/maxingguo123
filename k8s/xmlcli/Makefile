# Build/General constants
DOCKER_TAG ?= $(USER)_$(shell git log -1 --pretty=format:"%H")
PUSH_TAG ?= $(DOCKER_TAG)
REGISTRY ?= prt-registry.sova.intel.com
DOCKER_NAME ?= sandstone

docker-build:
	pip download -i https://intelpypi.pdx.intel.com/pythonsv/production pysvtools-xmlcli # Requires credentials
	unzip pysvtools.xmlcli*.zip
	mv pysvtools.xmlcli*/pysvtools ./pysvtools
	docker build $(DOCKER_EXTRA_ARGS) . -t $(DOCKER_NAME):$(DOCKER_TAG)

docker-push: docker-build
	$(foreach i,$(PUSH_TAG), \
        	docker tag $(DOCKER_NAME):$(DOCKER_TAG) $(REGISTRY)/$(DOCKER_NAME):$(i); \
        	docker push $(REGISTRY)/$(DOCKER_NAME):$(i);)

clean:
	rm -rf pysvtools*

.PHONY: docker
docker: clean docker-push
