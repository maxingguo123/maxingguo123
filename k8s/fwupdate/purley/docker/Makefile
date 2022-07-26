DOCKER_NAME := fwupdate
DOCKER_TAG := $(FW_VER)
PUSH_TAG ?= $(DOCKER_TAG) latest
REGISTRY ?= prt-registry.sova.intel.com
TMPDIR := temp-dir

all: docker-build

docker-build: 
	rm -rf $(TMPDIR)
	mkdir $(TMPDIR)
	cp $(FW_BIN) ./$(TMPDIR)/
	docker build -t $(DOCKER_NAME):$(DOCKER_TAG) .
	rm -rf ./$(TMPDIR)/


docker-test: docker-build
	docker run --rm --privileged -v /sys:/sys $(DOCKER_NAME):$(DOCKER_TAG)

docker-push: docker-build
	$(foreach i,$(PUSH_TAG), \
		docker tag $(DOCKER_NAME):$(DOCKER_TAG) $(REGISTRY)/$(DOCKER_NAME):$(i); \
		docker push $(REGISTRY)/$(DOCKER_NAME):$(i);)
