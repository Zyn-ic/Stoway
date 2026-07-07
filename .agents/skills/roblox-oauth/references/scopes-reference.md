# Scopes Reference

## Key Concepts

- Scopes define what an OAuth token is allowed to do.
- Roblox has identity scopes such as `openid` and `profile`, plus API-specific scopes for Open Cloud endpoints.
- Some endpoints require multiple scopes.
- The local OpenAPI artifact exposes required scopes through `x-roblox-scopes` and OAuth security metadata.

## Rules

- Request only the scopes the app needs right now.
- Add `openid` when an ID token or stable user identity is required.
- Add `profile` only when profile claims are needed, and only with `openid`.
- Check endpoint-level scope requirements before finalizing the consent screen.
- Reauthorize users after changing scopes.

## Patterns

### Scope selection workflow

```text
feature list
-> endpoints the app will call
-> required scopes for each endpoint
-> deduplicate
-> remove unused scopes
-> register only the final minimum set
```

### Identity scope choices

- `openid`: stable user ID and ID token.
- `openid profile`: richer user metadata from `userinfo`.

### Local scope lookup pattern

- Use `sources/creator-docs/reference/cloud/openapi.json`.
- Check `x-roblox-scopes` near the target operation.
- Confirm whether the endpoint exposes OAuth support metadata in the security section.

## Examples

- User profile display: `openid profile`.
- User-authorized inventory access: include the user-facing inventory read scope only if the feature actually needs private inventory visibility.
- One action endpoint plus identity: `openid` plus the exact action scope, not a broad unrelated scope set.
