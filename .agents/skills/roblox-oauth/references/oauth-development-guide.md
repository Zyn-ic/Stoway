# OAuth Development Guide

## Key Concepts

- Roblox supports authorization code flow with and without PKCE.
- PKCE adds a per-request code verifier and derived code challenge.
- `state` protects the callback against CSRF-style request forgery.
- `nonce` binds identity information when using OIDC claims.
- The callback may carry either success parameters or OAuth error parameters.

## Rules

- Use PKCE for all clients and require it for public clients.
- Generate a fresh `code_verifier`, `code_challenge`, and `state` for every authorization request.
- Use only unreserved characters for `code_verifier` and keep it 43 to 128 characters long.
- Set `code_challenge_method=S256`.
- Verify `state` before trusting the returned authorization `code`.
- Treat callback errors as first-class control flow, not rare exceptions.

## Patterns

### Authorization URL construction

```text
GET https://apis.roblox.com/oauth/v1/authorize
  ?client_id=<client_id>
  &redirect_uri=<redirect_uri>
  &scope=<space-delimited scopes>
  &response_type=code
  &state=<random value>
  &code_challenge=<pkce challenge>
  &code_challenge_method=S256
```

### Callback handling

- Success path: read `code`, verify `state`, continue to token exchange.
- Failure path: read `error`, `error_description`, and `state`, then stop or recover safely.

### Token exchange request

```text
POST /oauth/v1/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
code=<authorization code>
client_id=<client_id>
code_verifier=<original verifier>
```

### Token storage pattern

- Keep access tokens short-lived in memory or short-duration server storage.
- Keep refresh tokens only in trusted server-side storage.
- Replace the stored refresh token after every successful refresh.

## Examples

- Browser app: generate PKCE client-side, send the code to a trusted backend, and let the backend store refresh tokens.
- Server-rendered app: keep the secret and refresh token in backend storage, then issue an app session cookie to the browser.
