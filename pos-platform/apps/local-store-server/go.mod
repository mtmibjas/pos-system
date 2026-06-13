module github.com/mibjas/pos-platform/apps/local-store-server

go 1.25.0

require (
	connectrpc.com/connect v1.20.0
	github.com/coder/websocket v1.8.14
	github.com/golang-migrate/migrate/v4 v4.19.1
	github.com/google/uuid v1.6.0
	github.com/mibjas/pos-platform/packages/sdk-go v0.0.0-00010101000000-000000000000
	github.com/stretchr/testify v1.11.1
	golang.org/x/net v0.54.0
	google.golang.org/protobuf v1.36.11
	modernc.org/sqlite v1.50.1
)

// sdk-go lives in the same monorepo; resolved through go.work for builds
// and via this replace for `go mod tidy`.
replace github.com/mibjas/pos-platform/packages/sdk-go => ../../packages/sdk-go

require (
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/dustin/go-humanize v1.0.1 // indirect
	github.com/golang-jwt/jwt/v5 v5.3.1 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/ncruces/go-strftime v1.0.0 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	github.com/remyoudompheng/bigfft v0.0.0-20230129092748-24d4a6f8daec // indirect
	golang.org/x/crypto v0.52.0 // indirect
	golang.org/x/sys v0.45.0 // indirect
	golang.org/x/text v0.37.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	modernc.org/libc v1.72.3 // indirect
	modernc.org/mathutil v1.7.1 // indirect
	modernc.org/memory v1.11.0 // indirect
)
