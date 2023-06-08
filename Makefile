#!/usr/bin/make -f

PACKAGES=$(shell go list ./... | grep -v '/simulation')

BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git log -1 --format='%H')
SHELL := /bin/bash # Use bash syntax

# currently installed Go version
GO_MAJOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1)
GO_MINOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)

# minimum supported Go version
GO_MINIMUM_MAJOR_VERSION = $(shell cat go.mod | grep -E 'go [0-9].[0-9]+' | cut -d ' ' -f2 | cut -d'.' -f1)
GO_MINIMUM_MINOR_VERSION = $(shell cat go.mod | grep -E 'go [0-9].[0-9]+' | cut -d ' ' -f2 | cut -d'.' -f2)

RED=\033[0;31m
GREEN=\033[0;32m
LGREEN=\033[1;32m
NOCOLOR=\033[0m
GO_CURR_VERSION=$(shell echo -e "Current Go version: $(LGREEN)$(GO_MAJOR_VERSION).$(GREEN)$(GO_MINOR_VERSION)$(NOCOLOR)")
GO_VERSION_ERR_MSG=$(shell echo -e '$(RED)❌ ERROR$(NOCOLOR): Go version $(LGREEN)$(GO_MINIMUM_MAJOR_VERSION).$(GREEN)$(GO_MINIMUM_MINOR_VERSION)$(NOCOLOR)+ is required')

# don't override user values
ifeq (,$(VERSION))
	VERSION := $(shell git describe --tags)
	# if VERSION is empty, then populate it with branch's name and raw commit hash
	ifeq (,$(VERSION))
	VERSION := $(BRANCH)-$(COMMIT)
	endif
endif

SDK_PACK := $(shell go list -m github.com/cosmos/cosmos-sdk | sed  's/ /\@/g')
TM_VERSION := $(shell go list -m github.com/tendermint/tendermint | sed 's:.* ::')

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=aura \
	-X github.com/cosmos/cosmos-sdk/version.AppName=aurad \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
	-X github.com/tendermint/tendermint/version.TMCoreSemVer=$(TM_VERSION)

BUILD_FLAGS := -ldflags '$(ldflags)'

all: build install

install: check-go-version go.sum
	@echo "--> Installing aurad"
	@go install -mod=readonly $(BUILD_FLAGS) ./cmd/aurad

build: check-go-version go.sum
	@echo "--> Build aurad"
	@go build -mod=readonly $(BUILD_FLAGS) -o ./build/aurad ./cmd/aurad

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	GO111MODULE=on go mod verify

test: check-go-version
	@go test -mod=readonly $(PACKAGES)

clean:
	@rm -rf build

# Add check to make sure we are using the proper Go version before proceeding with anything
check-go-version:
	@echo '$(GO_CURR_VERSION)'
	@if [[ $(GO_MAJOR_VERSION) -eq $(GO_MINIMUM_MAJOR_VERSION) && $(GO_MINOR_VERSION) -ge $(GO_MINIMUM_MINOR_VERSION) ]]; then \
		exit 0; \
	elif [[ $(GO_MAJOR_VERSION) -lt $(GO_MINIMUM_MAJOR_VERSION) ]]; then \
		echo '$(GO_VERSION_ERR_MSG)'; \
		exit 1; \
	elif [[ $(GO_MINOR_VERSION) -lt $(GO_MINIMUM_MINOR_VERSION) ]]; then \
		echo '$(GO_VERSION_ERR_MSG)'; \
		exit 1; \
	fi