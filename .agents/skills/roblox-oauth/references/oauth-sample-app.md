# OAuth Sample App

## Key Concepts

- Roblox provides a Node.js sample app for OAuth 2.0.
- The sample uses authorization code flow without PKCE, so it is suitable only for confidential clients.
- The sample demonstrates localhost redirects, environment-variable configuration, token storage, and a simple authenticated action.
- The sample fetches the OIDC configuration dynamically.

## Rules

- Do not copy the sample's non-PKCE flow into a public client.
- Keep client credentials in environment variables, not in source files.
- Ensure the localhost port matches the registered redirect URL.
- Treat the sample as an integration pattern, not a justification to skip current best practices like PKCE.

## Patterns

### Local development setup

- Register scopes:
  - `openid`
  - `profile`
  - only the API scope the sample action needs
- Register redirect:
  - `http://localhost:3000/oauth/callback`
- Set environment variables:
  - `ROBLOX_CLIENT_ID`
  - `ROBLOX_CLIENT_SECRET`
  - optional `ROBLOX_PORT`

### What the sample does

```text
start Express server
-> fetch OIDC configuration
-> build OAuth client
-> redirect user to login
-> handle callback
-> store tokens in cookies
-> call an authenticated Open Cloud action
```

### Safe adaptation pattern

- Keep the sample's environment-variable and localhost wiring.
- Replace non-PKCE pieces with PKCE if building a modern production integration.

## Examples

- Quick local proof of concept: use the sample structure to validate redirect handling and token exchange.
- Production migration: preserve the route structure, but move to PKCE and server-side session management.
