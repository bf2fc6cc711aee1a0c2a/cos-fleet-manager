MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCS_DIR := $(PROJECT_PATH)/docs

.DEFAULT_GOAL := help
SHELL = bash

# The details of the application:
binary:=cos-fleet-manager

# The version needs to be different for each deployment because otherwise the
# cluster will not pull the new image from the internal registry:
version:=$(shell date +%s)

# Default namespace for local deployments
NAMESPACE ?= cos-fleet-manager-${USER}

# The name of the image repository needs to start with the name of an existing
# namespace because when the image is pushed to the internal registry of a
# cluster it will assume that that namespace exists and will try to create a
# corresponding image stream inside that namespace. If the namespace doesn't
# exist the push fails. This doesn't apply when the image is pushed to a public
# repository, like `docker.io` or `quay.io`.
image_repository:=$(NAMESPACE)/cos-fleet-manager

# Tag for the image:
image_tag:=$(version)

# In the development environment we are pushing the image directly to the image
# registry inside the development cluster. That registry has a different name
# when it is accessed from outside the cluster and when it is accessed from
# inside the cluster. We need the external name to push the image, and the
# internal name to pull it.
external_image_registry:=default-route-openshift-image-registry.apps-crc.testing
internal_image_registry:=image-registry.openshift-image-registry.svc:5000

image_registry:=quay.io

# Test image name that will be used for PR checks
test_image:=test/cos-fleet-manager

DOCKER_CONFIG="${PWD}/.docker"

# Default Variables
ENABLE_OCM_MOCK ?= false
OCM_MOCK_MODE ?= emulate-server
JWKS_URL ?= "https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/certs"
TOKEN_ISSUER_URL ?= "https://sso.redhat.com/auth/realms/redhat-external"
MAS_SSO_BASE_URL ?= "https://identity.api.stage.openshift.com"
MAS_SSO_REALM ?= "rhoas"
REDHAT_SSO_BASE_URL ?= "https://sso.redhat.com"
SSO_PROVIDER_TYPE ?= "redhat_sso"
SSO_SPECIAL_MANAGEMENT_ORG_ID ?= "13640203"
VAULT_KIND ?= tmp
VAULT_REGION ?= "us-east-1"
VAULT_SECRET_PREFIX_ENABLE ?= false
VAULT_SECRET_PREFIX ?= "managed-connectors"
CONNECTOR_ENABLE_UNASSIGNED_CONNECTORS ?= "false"
CONNECTOR_EVAL_DURATION ?= "48h"
CONNECTOR_NAMESPACE_LIFECYCLE_API ?= "false"
CONNECTORS_EVAL_NAMESPACE_QUOTA_PROFILE ?= "evaluation-profile"

GO := go
GOFMT := gofmt
# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell $(GO) env GOBIN))
GOBIN=$(shell $(GO) env GOPATH)/bin
else
GOBIN=$(shell $(GO) env GOBIN)
endif

LOCAL_BIN_PATH := ${PROJECT_PATH}/bin
# Add the project-level bin directory into PATH. Needed in order
# for `go generate` to use project-level bin directory binaries first
export PATH := ${LOCAL_BIN_PATH}:$(PATH)

GOLANGCI_LINT ?= $(LOCAL_BIN_PATH)/golangci-lint
golangci-lint:
ifeq (, $(shell which $(LOCAL_BIN_PATH)/golangci-lint 2> /dev/null))
	@{ \
	set -e ;\
	VERSION="v1.43.0" ;\
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/$${VERSION}/install.sh | sh -s -- -b ${LOCAL_BIN_PATH} $${VERSION} ;\
	}
endif

GOTESTSUM ?=$(LOCAL_BIN_PATH)/gotestsum
gotestsum:
ifeq (, $(shell which $(LOCAL_BIN_PATH)/gotestsum 2> /dev/null))
	@{ \
	set -e ;\
	GOTESTSUM_TMP_DIR=$$(mktemp -d) ;\
	cd $$GOTESTSUM_TMP_DIR ;\
	$(GO) mod init tmp ;\
	$(GO) get -d gotest.tools/gotestsum@v0.6.0 ;\
	mkdir -p ${LOCAL_BIN_PATH} ;\
	$(GO) build -o ${LOCAL_BIN_PATH}/gotestsum gotest.tools/gotestsum ;\
	rm -rf $$GOTESTSUM_TMP_DIR ;\
	}
endif

ifeq ($(shell uname -s | tr A-Z a-z), darwin)
        PGHOST:="127.0.0.1"
else
        PGHOST:="172.18.0.22"
endif

### Environment-sourced variables with defaults
# Can be overriden by setting environment var before running
# Example:
#   OCM_ENV=testing make run
#   export OCM_ENV=testing; make run
# Set the environment to development by default
ifndef OCM_ENV
	OCM_ENV:=integration
endif

ifndef TEST_SUMMARY_FORMAT
	TEST_SUMMARY_FORMAT=short-verbose
endif

# Enable Go modules:
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org
export GOPRIVATE=gitlab.cee.redhat.com

ifndef SERVER_URL
	SERVER_URL:=http://localhost:8000
endif

ifndef TEST_TIMEOUT
	TEST_TIMEOUT=5h
endif

# Prints a list of useful targets.
help:
	@echo ""
	@echo "Kafka Service Fleet Manager make targets"
	@echo ""
	@echo "make verify               	verify source code"
	@echo "make lint                 	run golangci-lint"
	@echo "make binary               	compile binaries"
	@echo "make install              	compile binaries and install in GOPATH bin"
	@echo "make run                  	run the application"
	@echo "make test                 	run unit tests"
	@echo "make code/fix             	format files"
	@echo "make image                	build docker image"
	@echo "make push                 	push docker image"
	@echo "make project              	create and use the cos-fleet-manager project"
	@echo "make clean                	delete temporary generated files"
	@echo "make setup/git/hooks      	setup git hooks"
	@echo "make keycloak/setup     	    setup mas sso clientId, clientSecret & crt"
	@echo "make redhatsso/setup         setup redhat sso clientId, clientSecret & crt"
	@echo "make kafkacert/setup         setup the kafka certificate used for Kafka Brokers"
	@echo "make observatorium/setup     setup observatorium secret used by CI"
	@echo "make docker/login/internal	login to an openshift cluster image registry"
	@echo "make image/build/push/internal  build and push image to an openshift cluster image registry."
	@echo "make deploy               	deploy the service via templates to an openshift cluster"
	@echo "make undeploy             	remove the service deployments from an openshift cluster"
	@echo "$(fake)"
.PHONY: help

# Set git hook path to .githooks/
.PHONY: setup/git/hooks
setup/git/hooks:
	git config core.hooksPath .githooks

# Checks if a GOPATH is set, or emits an error message
check-gopath:
ifndef GOPATH
	$(error GOPATH is not set)
endif
.PHONY: check-gopath

# Verifies that source passes standard checks.
verify: check-gopath
	$(GO) vet ./...
.PHONY: verify

# Runs our linter to verify that everything is following best practices
# Requires golangci-lint to be installed @ $(go env GOPATH)/bin/golangci-lint
lint: golangci-lint verify
	$(GOLANGCI_LINT) run ./...
.PHONY: lint

# Build binaries
# NOTE it may be necessary to use CGO_ENABLED=0 for backwards compatibility with centos7 if not using centos7
binary:
	$(GO) build ./cmd/cos-fleet-manager
.PHONY: binary

# Install
install: lint
	$(GO) install ./cmd/cos-fleet-manager
.PHONY: install

# bumps the kas-fleet-manager dependency.
bump-kfm: 
	$(GO) get -u github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager@main
	$(GO) mod tidy
.PHONY: bump-kfm

# Modify the go.mod to allow you to develop against a local copy of the kas-fleet-manager
add-local-kfm:
	echo "replace github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager => ../kas-fleet-manager" >> go.mod
	$(GO) mod tidy
.PHONY: add-replace-kfm
# Modify the go.mod to allow you build against checked in version of kas-fleet-manager
rm-local-kfm:
	sed -i 's:replace github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager => ../kas-fleet-manager::g' go.mod
	$(GO) mod tidy
.PHONY: rm-replace-kfm



PUBLIC_HOST_URL ?= http://localhost:8000
run:
	$(GO) run ./cmd/cos-fleet-manager serve --public-host-url=${PUBLIC_HOST_URL}
.PHONY: run

# Runs the unit tests.
#
# Args:
#   TESTFLAGS: Flags to pass to `go test`. The `-v` argument is always passed.
#
# Examples:
#   make test TESTFLAGS="-run TestSomething"
test: gotestsum
	OCM_ENV=testing $(GOTESTSUM) --junitfile reports/unit-tests.xml --format $(TEST_SUMMARY_FORMAT) -- -p 1 -v -count=1 $(TESTFLAGS) \
		$(shell go list ./... | grep -v /test)
.PHONY: test

# clean up code and dependencies
code/fix:
	@$(GO) mod tidy
	@$(GOFMT) -w `find . -type f -name '*.go' -not -path "./vendor/*"`
.PHONY: code/fix

db/setup:
	docker network create cos-fleet-manager-network || true
	docker run \
		--name cos-fleet-manager-db \
		--net cos-fleet-manager-network \
		-e POSTGRES_PASSWORD=$(shell cat secrets/db.password) \
		-e POSTGRES_USER=$(shell cat secrets/db.user) \
		-e POSTGRES_DB=$(shell cat secrets/db.name) \
		-p $(shell cat secrets/db.port):5432 \
		-d postgres:12.13
.PHONY: db/setup

db/teardown:
	docker stop cos-fleet-manager-db
	docker rm cos-fleet-manager-db
	docker network rm cos-fleet-manager-network
.PHONY: db/teardown

db/migrate:
	OCM_ENV=integration $(GO) run ./cmd/cos-fleet-manager migrate
.PHONY: db/migrate

db/login:
	docker exec \
		-u $(shell id -u) \
		-it cos-fleet-manager-db \
		/bin/bash -c \
		"PGPASSWORD=$(shell cat secrets/db.password) psql -d $(shell cat secrets/db.name) -U $(shell cat secrets/db.user)"
.PHONY: db/login

# Login to docker
docker/login:
	docker --config="${DOCKER_CONFIG}" login -u "${QUAY_USER}" -p "${QUAY_TOKEN}" quay.io
.PHONY: docker/login

# Login to the OpenShift internal registry
docker/login/internal:
	docker login -u kubeadmin -p $(shell oc whoami -t) $(shell oc get route default-route -n openshift-image-registry -o jsonpath="{.spec.host}")
.PHONY: docker/login/internal

# Set image build var defaults based on os
ifeq ($(shell uname -s | tr A-Z a-z), darwin)
CONTAINER_IMAGE_BUILD_PLATFORM ?= --platform linux/amd64
endif

# Build the binary and image
image/build:
	docker --config="${DOCKER_CONFIG}" build $(CONTAINER_IMAGE_BUILD_PLATFORM) -t "$(external_image_registry)/$(image_repository):$(image_tag)" .
.PHONY: image/build

image/build/dev: binary
	docker --config="${DOCKER_CONFIG}" build $(CONTAINER_IMAGE_BUILD_PLATFORM) -t "quay.io/rhoas/cos-fleet-manager:latest" .
.PHONY: image/build/dev

# Build and push the image
image/push: image/build
	docker --config="${DOCKER_CONFIG}" push "$(external_image_registry)/$(image_repository):$(image_tag)"
.PHONY: image/push

# build binary and image for OpenShift deployment
image/build/internal: IMAGE_TAG ?= $(image_tag)
image/build/internal: binary
	docker build $(CONTAINER_IMAGE_BUILD_PLATFORM) -t "$(shell oc get route default-route -n openshift-image-registry -o jsonpath="{.spec.host}")/$(image_repository):$(IMAGE_TAG)" .
.PHONY: image/build/internal

# push the image to the OpenShift internal registry
image/push/internal: IMAGE_TAG ?= $(image_tag)
image/push/internal:
	docker push "$(shell oc get route default-route -n openshift-image-registry -o jsonpath="{.spec.host}")/$(image_repository):$(IMAGE_TAG)"
.PHONY: image/push/internal

# build and push the image to an OpenShift cluster's internal registry
# namespace used in the image repository must exist on the cluster before running this command. Run `make deploy/project` to create the namespace if not available.
image/build/push/internal: image/build/internal image/push/internal
.PHONY: image/build/push/internal

# Build the binary and test image
image/build/test: binary
	docker build -t "$(test_image)" -f Dockerfile.integration.test .
.PHONY: image/build/test

# Run the test container
test/run: image/build/test
	docker run -u $(shell id -u) --net=host -p 9876:9876 -i "$(test_image)"
.PHONY: test/run

# TODO add integration tests
test/integration:
.PHONY: test/integration

# Setup for AWS credentials
aws/setup:
	@echo -n "$(AWS_ACCOUNT_ID)" > secrets/aws.accountid
	@echo -n "$(AWS_ACCESS_KEY)" > secrets/aws.accesskey
	@echo -n "$(AWS_SECRET_ACCESS_KEY)" > secrets/aws.secretaccesskey
	@echo -n "$(VAULT_ACCESS_KEY)" > secrets/vault/aws_access_key_id
	@echo -n "$(VAULT_SECRET_ACCESS_KEY)" > secrets/vault/aws_secret_access_key
	@echo -n "$(ROUTE53_ACCESS_KEY)" > secrets/aws.route53accesskey
	@echo -n "$(ROUTE53_SECRET_ACCESS_KEY)" > secrets/aws.route53secretaccesskey
.PHONY: aws/setup

# Setup for mas sso credentials
keycloak/setup:
	@echo -n "$(MAS_SSO_CLIENT_ID)" > secrets/keycloak-service.clientId
	@echo -n "$(MAS_SSO_CLIENT_SECRET)" > secrets/keycloak-service.clientSecret
	@echo -n "$(OSD_IDP_MAS_SSO_CLIENT_ID)" > secrets/osd-idp-keycloak-service.clientId
	@echo -n "$(OSD_IDP_MAS_SSO_CLIENT_SECRET)" > secrets/osd-idp-keycloak-service.clientSecret
.PHONY:keycloak/setup

redhatsso/setup:
	@echo -n "$(SSO_CLIENT_ID)" > secrets/redhatsso-service.clientId
	@echo -n "$(SSO_CLIENT_SECRET)" > secrets/redhatsso-service.clientSecret
.PHONY:redhatsso/setup

# OCM login
ocm/login:
	@ocm login --url="$(SERVER_URL)" --token="$(OCM_OFFLINE_TOKEN)"
.PHONY: ocm/login

# Setup OCM_OFFLINE_TOKEN and
# OCM Client ID and Secret should be set only when running inside docker in integration ENV)
ocm/setup: OCM_CLIENT_ID ?= ocm-ams-testing
ocm/setup: OCM_CLIENT_SECRET ?= 8f0c06c5-a558-4a78-a406-02deb1fd3f17
ocm/setup:
	@echo -n "$(OCM_OFFLINE_TOKEN)" > secrets/ocm-service.token
	@echo -n "" > secrets/ocm-service.clientId
	@echo -n "" > secrets/ocm-service.clientSecret
ifeq ($(OCM_ENV), integration)
	@if [[ -n "$(DOCKER_PR_CHECK)" ]]; then echo -n "$(OCM_CLIENT_ID)" > secrets/ocm-service.clientId; echo -n "$(OCM_CLIENT_SECRET)" > secrets/ocm-service.clientSecret; fi;
endif
.PHONY: ocm/setup

# create project where the service will be deployed in an OpenShift cluster
deploy/project:
	@-oc new-project $(NAMESPACE)
.PHONY: deploy/project

# deploy the postgres database required by the service to an OpenShift cluster
deploy/db:
	oc process -f ./templates/db-template.yml | oc apply -f - -n $(NAMESPACE)
.PHONY: deploy/db

# Deploys an Observatorium token refresher on an OpenShift cluster
deploy/token-refresher: ISSUER_URL ?= "https://sso.redhat.com/auth/realms/redhat-external"
deploy/token-refresher: OBSERVATORIUM_TOKEN_REFRESHER_IMAGE ?= "quay.io/rhoas/mk-token-refresher"
deploy/token-refresher: OBSERVATORIUM_TOKEN_REFRESHER_IMAGE_TAG ?= "latest"
deploy/token-refresher: OBSERVATORIUM_URL ?= "https://observatorium-mst.api.stage.openshift.com/api/metrics/v1/rhoc"
deploy/token-refresher:
	@-oc process -f ./templates/observatorium-token-refresher.yml \
		-p ISSUER_URL=${ISSUER_URL} \
		-p OBSERVATORIUM_URL=${OBSERVATORIUM_URL} \
		-p OBSERVATORIUM_TOKEN_REFRESHER_IMAGE=${OBSERVATORIUM_TOKEN_REFRESHER_IMAGE} \
		-p OBSERVATORIUM_TOKEN_REFRESHER_IMAGE_TAG=${OBSERVATORIUM_TOKEN_REFRESHER_IMAGE_TAG} \
		 | oc apply -f - -n $(NAMESPACE)
.PHONY: deploy/token-refresher

# deploys the secrets required by the service to an OpenShift cluster
deploy/secrets:
	@oc get service/cos-fleet-manager-db -n $(NAMESPACE) || (echo "Database is not deployed, please run 'make deploy/db'"; exit 1)
	@oc process -f ./templates/secrets-template.yml \
		-p OCM_SERVICE_CLIENT_ID="$(OCM_SERVICE_CLIENT_ID)" \
		-p OCM_SERVICE_CLIENT_SECRET="$(OCM_SERVICE_CLIENT_SECRET)" \
		-p OCM_SERVICE_TOKEN="$(OCM_SERVICE_TOKEN)" \
		-p OBSERVATORIUM_SERVICE_TOKEN="$(OBSERVATORIUM_SERVICE_TOKEN)" \
		-p AWS_ACCESS_KEY="$(AWS_ACCESS_KEY)" \
		-p AWS_ACCOUNT_ID="$(AWS_ACCOUNT_ID)" \
		-p AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)" \
		-p MAS_SSO_CLIENT_ID="${MAS_SSO_CLIENT_ID}" \
		-p MAS_SSO_CLIENT_SECRET="${MAS_SSO_CLIENT_SECRET}" \
		-p MAS_SSO_CRT="${MAS_SSO_CRT}" \
		-p SSO_CLIENT_ID="${SSO_CLIENT_ID}" \
		-p SSO_CLIENT_SECRET="${SSO_CLIENT_SECRET}" \
		-p ROUTE53_ACCESS_KEY="$(ROUTE53_ACCESS_KEY)" \
		-p ROUTE53_SECRET_ACCESS_KEY="$(ROUTE53_SECRET_ACCESS_KEY)" \
		-p VAULT_ACCESS_KEY="$(VAULT_ACCESS_KEY)" \
		-p VAULT_SECRET_ACCESS_KEY="$(VAULT_SECRET_ACCESS_KEY)" \
		-p OBSERVABILITY_RHSSO_LOGS_CLIENT_ID="$(shell ([ -s './secrets/rhsso-logs.clientId' ] && [ -z '${OBSERVABILITY_RHSSO_LOGS_CLIENT_ID}' ]) && cat ./secrets/rhsso-logs.clientId || echo '${OBSERVABILITY_RHSSO_LOGS_CLIENT_ID}')" \
		-p OBSERVABILITY_RHSSO_LOGS_SECRET="$(shell ([ -s './secrets/rhsso-logs.clientSecret' ] && [ -z '${OBSERVABILITY_RHSSO_LOGS_SECRET}' ]) && cat ./secrets/rhsso-logs.clientSecret || echo '${OBSERVABILITY_RHSSO_LOGS_SECRET}')" \
		-p OBSERVABILITY_RHSSO_METRICS_CLIENT_ID="$(shell ([ -s './secrets/rhsso-metrics.clientId' ] && [ -z '${OBSERVABILITY_RHSSO_METRICS_CLIENT_ID}' ]) && cat ./secrets/rhsso-metrics.clientId || echo '${OBSERVABILITY_RHSSO_METRICS_CLIENT_ID}')" \
		-p OBSERVABILITY_RHSSO_METRICS_SECRET="$(shell ([ -s './secrets/rhsso-metrics.clientSecret' ] && [ -z '${OBSERVABILITY_RHSSO_METRICS_SECRET}' ]) && cat ./secrets/rhsso-metrics.clientSecret || echo '${OBSERVABILITY_RHSSO_METRICS_SECRET}')" \
		-p OBSERVABILITY_RHSSO_GRAFANA_CLIENT_ID="${OBSERVABILITY_RHSSO_GRAFANA_CLIENT_ID}" \
		-p OBSERVABILITY_RHSSO_GRAFANA_CLIENT_SECRET="${OBSERVABILITY_RHSSO_GRAFANA_CLIENT_SECRET}" \
		| oc apply -f - -n $(NAMESPACE)
.PHONY: deploy/secrets

deploy/envoy:
	@oc apply -f ./templates/envoy-config-configmap.yml -n $(NAMESPACE)
.PHONY: deploy/envoy

deploy/metadata:
	@oc process -f ./templates/connector-metadata-camel-template.yaml | oc apply -f - -n $(NAMESPACE)
	@oc process -f ./templates/connector-metadata-debezium-template.yaml | oc apply -f - -n $(NAMESPACE)
.PHONY: deploy/metadata

deploy/route:
	@oc process -f ./templates/route-template.yml | oc apply -f - -n $(NAMESPACE)
.PHONY: deploy/route

# deploy service via templates to an OpenShift cluster
deploy: IMAGE_REGISTRY ?= $(image_registry)
deploy: IMAGE_REPOSITORY ?= $(image_repository)
deploy: IMAGE_TAG ?= $(image_tag)
deploy: OCM_URL ?= "https://api.stage.openshift.com"
deploy: MAS_SSO_BASE_URL ?= "https://identity.api.stage.openshift.com"
deploy: MAS_SSO_REALM ?= "rhoas"
deploy: ADMIN_API_SSO_BASE_URL ?= "https://auth.redhat.com"
deploy: ADMIN_API_SSO_ENDPOINT_URI ?= "/auth/realms/EmployeeIDP"
deploy: ADMIN_API_SSO_REALM ?= "EmployeeIDP"
deploy: ADMIN_AUTHZ_CONFIG ?= "[{method: GET, roles: [cos-fleet-manager-admin-read, cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: PATCH, roles: [cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: PUT, roles: [cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: POST, roles: [cos-fleet-manager-admin-full]}, {method: DELETE, roles: [cos-fleet-manager-admin-full]}]"
deploy: OSD_IDP_MAS_SSO_REALM ?= "rhoas-kafka-sre"
deploy: SERVICE_PUBLIC_HOST_URL ?= "https://api.openshift.com"
deploy: REPLICAS ?= "1"
deploy: ENABLE_DB_DEBUG ?= "false"
deploy: deploy/db
deploy: deploy/secrets deploy/envoy deploy/metadata deploy/token-refresher deploy/route
	@oc process -f ./templates/connectors-quota-configuration.yml | oc apply -f - -n $(NAMESPACE)
	@oc create -f ./templates/connector-catalog-configmap.yml -n $(NAMESPACE) || true
	@oc process -f ./templates/service-template.yml \
		-p ENVIRONMENT="$(OCM_ENV)" \
		-p IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		-p IMAGE_REPOSITORY=$(IMAGE_REPOSITORY) \
		-p IMAGE_TAG=$(IMAGE_TAG) \
		-p ENABLE_OCM_MOCK=$(ENABLE_OCM_MOCK) \
		-p ENABLE_DB_DEBUG="$(ENABLE_DB_DEBUG)" \
		-p OCM_MOCK_MODE=$(OCM_MOCK_MODE) \
		-p OCM_URL="$(OCM_URL)" \
		-p JWKS_URL="$(JWKS_URL)" \
		-p TOKEN_ISSUER_URL="${TOKEN_ISSUER_URL}" \
		-p MAS_SSO_BASE_URL="$(MAS_SSO_BASE_URL)" \
		-p MAS_SSO_REALM="$(MAS_SSO_REALM)" \
		-p OSD_IDP_MAS_SSO_REALM="$(OSD_IDP_MAS_SSO_REALM)" \
		-p REDHAT_SSO_BASE_URL="$(REDHAT_SSO_BASE_URL)" \
		-p SSO_PROVIDER_TYPE="$(SSO_PROVIDER_TYPE)" \
		-p SSO_SPECIAL_MANAGEMENT_ORG_ID="$(SSO_SPECIAL_MANAGEMENT_ORG_ID)" \
		-p ADMIN_API_SSO_BASE_URL="${ADMIN_API_SSO_BASE_URL}" \
		-p ADMIN_API_SSO_ENDPOINT_URI="${ADMIN_API_SSO_ENDPOINT_URI}" \
		-p ADMIN_API_SSO_REALM="${ADMIN_API_SSO_REALM}" \
		-p ADMIN_AUTHZ_CONFIG="${ADMIN_AUTHZ_CONFIG}" \
		-p VAULT_KIND=$(VAULT_KIND) \
		-p VAULT_REGION=$(VAULT_REGION) \
		-p VAULT_SECRET_PREFIX_ENABLE=$(VAULT_SECRET_PREFIX_ENABLE) \
		-p VAULT_SECRET_PREFIX=$(VAULT_SECRET_PREFIX) \
		-p CONNECTOR_EVAL_ORGANIZATIONS=$(CONNECTOR_EVAL_ORGANIZATIONS) \
		-p CONNECTOR_ENABLE_UNASSIGNED_CONNECTORS=$(CONNECTOR_ENABLE_UNASSIGNED_CONNECTORS) \
		-p CONNECTOR_EVAL_DURATION=$(CONNECTOR_EVAL_DURATION) \
		-p CONNECTOR_NAMESPACE_LIFECYCLE_API=$(CONNECTOR_NAMESPACE_LIFECYCLE_API) \
		-p CONNECTORS_EVAL_NAMESPACE_QUOTA_PROFILE=$(CONNECTORS_EVAL_NAMESPACE_QUOTA_PROFILE) \
		-p CONNECTORS_SUPPORTED_CHANNELS=$(CONNECTORS_SUPPORTED_CHANNELS) \
		-p SERVICE_PUBLIC_HOST_URL="$(SERVICE_PUBLIC_HOST_URL)" \
		-p REPLICAS="$(REPLICAS)" \
		| oc apply -f - -n $(NAMESPACE)
.PHONY: deploy

# remove service deployments from an OpenShift cluster
undeploy: IMAGE_REGISTRY ?= $(internal_image_registry)
undeploy: IMAGE_REPOSITORY ?= $(image_repository)
undeploy:
	@-oc process -f ./templates/db-template.yml | oc delete -f - -n $(NAMESPACE)
	@-oc process -f ./templates/secrets-template.yml | oc delete -f - -n $(NAMESPACE)
	@-oc process -f ./templates/route-template.yml | oc delete -f - -n $(NAMESPACE)
	@-oc delete -f ./templates/envoy-config-configmap.yml -n $(NAMESPACE)
	@-oc delete -f ./templates/connector-metadata-camel-configmap.yml -n $(NAMESPACE)
	@-oc delete -f ./templates/connector-metadata-debezium-configmap.yml -n $(NAMESPACE)
	@-oc process -f ./templates/connectors-quota-configuration.yml | oc delete -f - -n $(NAMESPACE)
	@-oc process -f ./templates/service-template.yml \
		-p IMAGE_REGISTRY=$(IMAGE_REGISTRY) \
		-p IMAGE_REPOSITORY=$(IMAGE_REPOSITORY) \
		| oc delete -f - -n $(NAMESPACE)
.PHONY: undeploy
