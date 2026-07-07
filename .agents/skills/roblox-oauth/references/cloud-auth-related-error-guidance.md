# Cloud Auth Related Error Guidance

## Key Concepts

- Roblox OAuth failures can happen in the browser redirect step, token step, or later when bearer tokens hit Open Cloud endpoints.
- Open Cloud error formats vary across v1, v2, and gateway layers.
- Scope problems and resource-authorization problems are related but not identical.
- OAuth helper endpoints such as `token/introspect` and `token/resources` are useful for narrowing the failure source.

## Rules

- Start by locating the failing stage: authorize, callback, token exchange, refresh, or resource API call.
- Treat missing or mismatched `state` as a flow integrity failure, not a retriable API error.
- Treat `INVALID_ARGUMENT` as malformed request data first.
- Treat `INSUFFICIENT_SCOPE` or `PERMISSION_DENIED` as missing scope or missing permission first.
- Treat `RESOURCE_EXHAUSTED` or HTTP 429 as quota or rate pressure and back off.
- Treat token introspection as activity checking only; use `token/resources` when resource access is uncertain.

## Patterns

### Failure triage

```text
redirect failed?
-> inspect error and error_description from callback

token request failed?
-> verify grant_type, code or refresh token, client auth, redirect URI, and PKCE verifier

API call failed with bearer token?
-> verify scope, token expiry, and resource grant coverage
```

### Common Open Cloud auth errors

- `INVALID_ARGUMENT`:
  - malformed form body
  - bad redirect URI
  - bad or reused authorization code
- `PERMISSION_DENIED` or `INSUFFICIENT_SCOPE`:
  - missing endpoint scope
  - user lacks access to the target resource
  - token does not cover the target universe, group, or user resource
- `RESOURCE_EXHAUSTED`:
  - too many requests
- `UNAVAILABLE`:
  - transient platform issue; retry carefully if safe

### Useful checks

- Expired access token: refresh the session.
- Refresh fails after prior successful refresh: check whether the old refresh token was mistakenly reused.
- Introspection says active but API still fails: inspect scopes and call `token/resources`.

## Examples

- Callback returns `error` and `error_description`: stop and surface the authorization failure cleanly to the user.
- Bearer token gets 403 on a universe action: verify both the endpoint scope and that the authorizing user granted that universe resource.
- Refresh path breaks after one success: likely refresh-token rotation was ignored and stale storage is being reused.
