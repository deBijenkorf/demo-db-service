# Makefile for releasing podinfo
#
# The release version is controlled from pkg/version

TAG?=latest
APP_NAME:=podinfo
DOCKER_REPOSITORY:=eu.gcr.io/dbk-ecom-cicd
DOCKER_IMAGE_NAME:=$(DOCKER_REPOSITORY)/$(APP_NAME)
GIT_COMMIT:=$(shell git describe --dirty --always)
GITVER:=$(shell git rev-parse --short=7 HEAD)
PROJECTVER:=$(shell grep 'VERSION' pkg/version/version.go | awk '{ print $$4 }' | tr -d '"')
VERSION:=$(PROJECTVER)-$(GITVER)
NAMESPACE := $(APP_NAME)
HELM3_CHART_DIR := ./helm3/$(APP_NAME)
CONTEXT_DBK_DEV:=gke_dbk-ecom-dev_europe-west4_dbk-dev
EXTRA_RUN_ARGS?=

.PHONY: docker_build
docker_build:
	docker build . -t $(DOCKER_IMAGE_NAME):$(VERSION) --no-cache
	docker push $(DOCKER_IMAGE_NAME):$(VERSION)

.PHONY: export_version
export_version:
	printf "VERSION=$(VERSION)\n" > version.txt

.PHONY: ci_build
ci_build: docker_build export_version

.PHONY: deploy
deploy:
	helm3 secrets upgrade --install $(APP_NAME)-$(HELM3_TARGET_ENV) $(HELM3_CHART_DIR) \
		--values $(HELM3_CHART_DIR)/values.yaml \
		--set image.tag=$(VERSION) \
		--namespace $(NAMESPACE) --kube-context $(HELM3_TARGET_CONTEXT)

.PHONY: deploy_sit
deploy_sit: HELM3_TARGET_ENV = sit
deploy_sit: HELM3_TARGET_CONTEXT = ${CONTEXT_DBK_DEV}
deploy_sit: deploy

.PHONY: deploy_bau
deploy_bau: HELM3_TARGET_ENV = bau
deploy_bau: HELM3_TARGET_CONTEXT = ${CONTEXT_DBK_DEV}
deploy_bau: deploy

.PHONY: deploy_prod
deploy_prod: HELM3_TARGET_ENV = prod
deploy_prod: HELM3_TARGET_CONTEXT = ${CONTEXT_DBK_PROD}
deploy_prod: deploy

run:
	go run -ldflags "-s -w -X github.com/stefanprodan/podinfo/pkg/version.REVISION=$(GIT_COMMIT)" cmd/podinfo/* \
	--level=debug --grpc-port=9999 --backend-url=https://httpbin.org/status/401 --backend-url=https://httpbin.org/status/500 \
	--ui-logo=https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif $(EXTRA_RUN_ARGS)

test:
	go test -v -race ./...

build:
	GIT_COMMIT=$$(git rev-list -1 HEAD) && CGO_ENABLED=0 go build  -ldflags "-s -w -X github.com/stefanprodan/podinfo/pkg/version.REVISION=$(GIT_COMMIT)" -a -o ./bin/podinfo ./cmd/podinfo/*
	GIT_COMMIT=$$(git rev-list -1 HEAD) && CGO_ENABLED=0 go build  -ldflags "-s -w -X github.com/stefanprodan/podinfo/pkg/version.REVISION=$(GIT_COMMIT)" -a -o ./bin/podcli ./cmd/podcli/*

fmt:
	gofmt -l -s -w ./
	goimports -l -w ./

build-charts:
	helm lint charts/*
	helm package charts/*

build-container:
	docker build -t $(DOCKER_IMAGE_NAME):$(VERSION) .

build-base:
	docker build -f Dockerfile.base -t $(DOCKER_REPOSITORY)/podinfo-base:latest .

push-base: build-base
	docker push $(DOCKER_REPOSITORY)/podinfo-base:latest

test-container:
	@docker rm -f podinfo || true
	@docker run -dp 9898:9898 --name=podinfo $(DOCKER_IMAGE_NAME):$(VERSION)
	@docker ps
	@TOKEN=$$(curl -sd 'test' localhost:9898/token | jq -r .token) && \
	curl -sH "Authorization: Bearer $${TOKEN}" localhost:9898/token/validate | grep test

push-container:
	docker tag $(DOCKER_IMAGE_NAME):$(VERSION) $(DOCKER_IMAGE_NAME):latest
	docker push $(DOCKER_IMAGE_NAME):$(VERSION)
	docker push $(DOCKER_IMAGE_NAME):latest


version-set:
	@next="$(TAG)" && \
	current="$(VERSION)" && \
	sed -i '' "s/$$current/$$next/g" pkg/version/version.go && \
	sed -i '' "s/tag: $$current/tag: $$next/g" charts/podinfo/values.yaml && \
	sed -i '' "s/appVersion: $$current/appVersion: $$next/g" charts/podinfo/Chart.yaml && \
	sed -i '' "s/version: $$current/version: $$next/g" charts/podinfo/Chart.yaml && \
	sed -i '' "s/podinfo:$$current/podinfo:$$next/g" kustomize/deployment.yaml && \
	sed -i '' "s/podinfo:$$current/podinfo:$$next/g" deploy/webapp/frontend/deployment.yaml && \
	sed -i '' "s/podinfo:$$current/podinfo:$$next/g" deploy/webapp/backend/deployment.yaml && \
	sed -i '' "s/podinfo:$$current/podinfo:$$next/g" deploy/bases/frontend/deployment.yaml && \
	sed -i '' "s/podinfo:$$current/podinfo:$$next/g" deploy/bases/backend/deployment.yaml && \
	echo "Version $$next set in code, deployment, chart and kustomize"

release:
	git tag $(VERSION)
	git push origin $(VERSION)

swagger:
	go get github.com/swaggo/swag/cmd/swag
	cd pkg/api && $$(go env GOPATH)/bin/swag init -g server.go