# pos-platform — top-level Makefile

.PHONY: help proto-gen openapi-gen build test fmt lint tidy clean \
	desktop-run desktop-test desktop-analyze desktop-codegen

help:
	@echo "pos-platform targets:"
	@echo "  proto-gen        Regenerate Protobuf for Go + Dart"
	@echo "  openapi-gen      Regenerate OpenAPI clients (TODO)"
	@echo "  build            Build all Go binaries"
	@echo "  test             Run all Go + Dart tests"
	@echo "  fmt              Format all Go code"
	@echo "  lint             Run linters (golangci-lint) (TODO)"
	@echo "  tidy             go mod tidy across the workspace"
	@echo "  clean            Remove build artifacts"
	@echo "  desktop-run      Launch the macOS POS client (apps/desktop-pos)"
	@echo "  desktop-test     Run desktop client tests"
	@echo "  desktop-analyze  flutter analyze on desktop client"
	@echo "  desktop-codegen  Regenerate Riverpod codegen (.g.dart) for desktop client"

proto-gen:
	cd packages/proto && buf lint
	cd packages/proto && buf generate
	cd packages/proto && PATH="$$PATH:$$HOME/.pub-cache/bin" \
		buf generate --template buf.gen.dart.yaml --include-imports --include-wkt
	cd packages/sdk-go && go mod tidy
	cd packages/sdk-dart && dart pub get
	cd apps/desktop-pos && flutter pub get

openapi-gen:
	@echo "TODO: invoke oapi-codegen / openapi-generator"

build:
	cd apps/local-store-server && go build ./...
	cd apps/cloud-api && go build ./...

# Note: desktop client tests are intentionally excluded from `make test`
# because Flutter/Dart pulls in a heavier toolchain. Run `make desktop-test`
# (or the full umbrella below) when iterating on the client.
test:
	cd apps/local-store-server && go test ./...
	cd apps/cloud-api && go test ./...
	cd packages/sdk-go && go test ./...
	cd packages/sdk-dart && dart test

fmt:
	cd apps/local-store-server && go fmt ./...
	cd apps/cloud-api && go fmt ./...
	cd packages/sdk-go && go fmt ./...

lint:
	@echo "TODO: golangci-lint run ./..."

tidy:
	cd apps/local-store-server && go mod tidy
	cd apps/cloud-api && go mod tidy
	cd packages/sdk-go && go mod tidy

clean:
	cd apps/local-store-server && go clean ./...
	cd apps/cloud-api && go clean ./...
	cd apps/desktop-pos && flutter clean

# --- desktop client (Flutter / macOS) -------------------------------------
desktop-run:
	cd apps/desktop-pos && flutter run -d macos

desktop-test:
	cd apps/desktop-pos && flutter test

desktop-analyze:
	cd apps/desktop-pos && flutter analyze

desktop-codegen:
	cd apps/desktop-pos && dart run build_runner build --delete-conflicting-outputs

# --- dev utilities --------------------------------------------------------
# Populates the local SQLite DB with a GST-18 tax category and ~6 demo
# items. Idempotent — re-run any time you blow away the DB.
seed-demo:
	cd apps/local-store-server && go run ./cmd/seed-demo
