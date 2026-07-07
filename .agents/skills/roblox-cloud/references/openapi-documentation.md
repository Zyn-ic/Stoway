# OpenAPI Documentation

## Key Concepts

- Roblox publishes a unified OpenAPI document at sources/creator-docs/reference/cloud/openapi.json.
- The document follows OpenAPI 3.0.4 and covers the Roblox Cloud API surface.
- The spec is useful for Swagger, Postman, code generation, validation tooling, and direct schema inspection.
- Roblox adds vendor extensions that capture metadata not expressed by base OpenAPI alone.

## Rules

- Use the spec for exact path templates, parameter shapes, request bodies, and schemas.
- Inspect vendor extensions before generating or calling clients blindly.
- Treat the document as a generated artifact under active development and verify suspicious details against published docs or narrower JSON files.
- Do not turn spec usage into OAuth flow implementation inside this skill.

## Patterns

### High-value vendor extensions

- x-roblox-stability: release state such as beta.
- x-roblox-deprecated: extra deprecation guidance.
- x-roblox-alternatives: replacement guidance where present.
- x-roblox-rate-limits: per-authentication quota metadata.
- x-roblox-scopes: required scopes.
- x-roblox-engine-usability: whether the endpoint is usable from HttpService.

### What to inspect per operation

1. operationId
2. parameters
3. requestBody
4. responses
5. security
6. x-roblox-scopes
7. x-roblox-rate-limits
8. x-roblox-engine-usability

### Minimal extension example

```text
operationId: Cloud_UpdateUniverse
x-roblox-scopes: universe:write
x-roblox-engine-usability: apiKeyWithHttpService = true
```

## Examples

### Generate a client safely

- Use openapi.json as the source, then manually review generated auth handling, polling models, and field-mask support before shipping.

### Check engine support

- Read x-roblox-engine-usability.apiKeyWithHttpService before assuming an endpoint can be called from a Roblox server.

### Check rate limits

- Read x-roblox-rate-limits to estimate batching and retry pressure before load-testing the integration.
