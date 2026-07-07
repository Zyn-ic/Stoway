# OAuth Reference

## Key Concepts

- The OAuth base URL is `https://apis.roblox.com/oauth`.
- Core endpoints are authorize, token, introspect, resources, revoke, userinfo, and the OIDC discovery document.
- Authorization codes are short-lived and single-use.
- Access tokens are bearer tokens for API access.
- Refresh tokens renew the session and rotate.

## Rules

- Send users to `GET /v1/authorize` to start the flow.
- Exchange codes or refresh tokens at `POST /v1/token`.
- Use `POST /v1/token/introspect` for token activity and claims, not resource authorization.
- Use `POST /v1/token/resources` to check which resources the token can access.
- Use `POST /v1/token/revoke` with the refresh token to end the authorization session.
- Use `GET /v1/userinfo` only with a bearer access token.

## Patterns

### Token lifetimes and reuse

- Authorization code:
  - valid for 1 minute
  - redeemable once
- Access token:
  - valid for about 15 minutes
  - reusable until expiry or revocation
- Refresh token:
  - valid for about 90 days
  - single-use for refresh

### Introspection versus resources

- `introspect`: "Is this token active and what claims does it carry?"
- `resources`: "What Roblox resources did the user actually grant access to?"

### OIDC discovery

- Use `GET /.well-known/openid-configuration` to discover:
  - authorization endpoint
  - token endpoint
  - introspection endpoint
  - revocation endpoint
  - userinfo endpoint
  - supported scopes and claims

## Examples

- Identity-only check: request `openid`, exchange the code, then call `/v1/userinfo`.
- Resource-aware app: after token exchange, call `/v1/token/resources` before showing a universe picker or action UI.
