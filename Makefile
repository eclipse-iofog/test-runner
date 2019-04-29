SHELL = /bin/bash
OS = $(shell uname -s)

# Project variables
IMAGE = iofog/test-runner
BRANCH ?= $(TRAVIS_BRANCH)
COMMIT_HASH ?= $(shell git rev-parse --short HEAD 2>/dev/null)
RELEASE_TAG ?= 0.0.0

.PHONY: build-img
build-img: ## Builds docker image for the scheduler
	docker build --rm -t $(IMAGE):latest -f build/Dockerfile .

.PHONY: push-img
push-img:
	@echo $(DOCKER_PASS) | docker login -u $(DOCKER_USER) --password-stdin
ifeq ($(BRANCH), master)
	# Master branch
	docker push $(IMAGE):latest
	docker tag $(IMAGE):latest $(IMAGE):$(RELEASE_TAG)
	docker push $(IMAGE):$(RELEASE_TAG)
endif
ifneq (,$(findstring release,$(BRANCH)))
	# Release branch
	docker tag $(IMAGE):latest $(IMAGE):rc-$(RELEASE_TAG)
	docker push $(IMAGE):rc-$(RELEASE_TAG)
else
	# Develop and feature branches
	docker tag $(IMAGE):latest $(IMAGE)-$(BRANCH):latest
	docker push $(IMAGE)-$(BRANCH):latest
	docker tag $(IMAGE):latest $(IMAGE)-$(BRANCH):$(COMMIT_HASH)
	docker push $(IMAGE)-$(BRANCH):$(COMMIT_HASH)
endif