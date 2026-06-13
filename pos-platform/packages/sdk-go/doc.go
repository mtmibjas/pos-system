// Package sdkgo is the umbrella for shared Go code used by both apps.
//
// Expected sub-packages (TBD as implementation proceeds):
//   - openapi/ — generated OpenAPI clients (cloud-api consumers)
//   - protogen/ — generated Protobuf types (re-exported for ergonomic use)
//   - sync/    — small helpers shared by local-store-server and cloud-api
//
// Do not put business logic here. Business rules live in apps/* or in
// language-agnostic form in packages/shared-domain/.
package sdkgo
