# If VERSION isn't provided by Packit/CI, fall back to latest tag or 0.0.0
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)
PROJECT := go-fdo-client
# Full commit SHA (rpmbuild may expect this on PR/no-tag builds)
GITREV  := $(shell git rev-parse HEAD)

.PHONY: all build tidy fmt vet test
# Default target
all: build test

# Build the Go project
build: tidy fmt vet
	go build

tidy:
	go mod tidy

fmt:
	go fmt ./...

vet:
	go vet -v ./...

test:
	go test -v ./...

# Packit helpers
.PHONY: vendor-tarball packit-create-archive vendor-licenses

vendor-tarball:
	# Use system Go toolchain; create vendor tarball
	GOTOOLCHAIN=local go_vendor_archive create --config ./go-vendor-tools.toml .
	@mv -f vendor.tar.bz2 $(PROJECT)-$(VERSION)-vendor.tar.bz2
	@cp -f $(PROJECT)-$(VERSION)-vendor.tar.bz2 $(PROJECT)-$(GITREV)-vendor.tar.bz2

packit-create-archive: vendor-tarball
	# Always archive HEAD; emit both VERSION-named and SHA-named tarballs
	git archive --format=tar --prefix=$(PROJECT)-$(VERSION)/ HEAD | gzip > $(PROJECT)-$(VERSION).tar.gz
	@cp -f $(PROJECT)-$(VERSION).tar.gz $(PROJECT)-$(GITREV).tar.gz
	@ls -1t $(PROJECT)-$(VERSION).tar.gz | head -n1

vendor-licenses:
	go_vendor_license --config ./go-vendor-tools.toml .

