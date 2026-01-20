# ContextFort Native Messaging Proxy (Go)
# Build targets for cross-platform compilation

BINARY_NAME=native-messaging-proxy
VERSION=$(shell cat ../VERSION)

# Go build flags
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -s -w"

.PHONY: all build build-mac build-linux build-windows clean install test

all: build

build:
	@echo "Building for current platform..."
	go build $(LDFLAGS) -o ../bin/$(BINARY_NAME) main.go

build-mac:
	@echo "Building for macOS (amd64)..."
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o ../bin/$(BINARY_NAME)-darwin-amd64 main.go
	@echo "Building for macOS (arm64)..."
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o ../bin/$(BINARY_NAME)-darwin-arm64 main.go
	@echo "Creating universal binary..."
	lipo -create -output ../bin/$(BINARY_NAME) \
		../bin/$(BINARY_NAME)-darwin-amd64 \
		../bin/$(BINARY_NAME)-darwin-arm64
	rm ../bin/$(BINARY_NAME)-darwin-amd64 ../bin/$(BINARY_NAME)-darwin-arm64

build-linux:
	@echo "Building for Linux (amd64)..."
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o ../bin/$(BINARY_NAME)-linux-amd64 main.go

build-windows:
	@echo "Building for Windows (amd64)..."
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o ../bin/$(BINARY_NAME)-windows-amd64.exe main.go

clean:
	@echo "Cleaning build artifacts..."
	rm -f ../bin/$(BINARY_NAME) ../bin/$(BINARY_NAME)-*

install: build
	@echo "Installing to /usr/local/bin..."
	sudo cp ../bin/$(BINARY_NAME) /usr/local/bin/

test:
	@echo "Running tests..."
	go test -v ./...

# Development targets
dev: build
	@echo "Running in development mode..."
	../bin/$(BINARY_NAME)

fmt:
	@echo "Formatting code..."
	go fmt ./...

lint:
	@echo "Linting code..."
	golangci-lint run

# Build all platforms
all-platforms: build-mac build-linux build-windows
	@echo "All platforms built:"
	@ls -lh ../bin/$(BINARY_NAME)*

# Generate installation packages
package-mac: build-mac
	@echo "Packaging for macOS..."
	cd ../installer/macos && ./build-pkg.sh

package-windows: build-windows
	@echo "Packaging for Windows..."
	cd ../installer/windows && powershell -File build-msi.ps1
