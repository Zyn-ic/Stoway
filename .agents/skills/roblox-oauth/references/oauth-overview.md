# OAuth Overview

## Key Concepts

- Roblox Open Cloud OAuth 2.0 is for delegated access to protected Roblox resources.
- The main roles are resource owner, client, authorization server, and resource server.
- Roblox supports authorization code flow and authorization code flow with PKCE.
- PKCE is recommended for all clients and required for public clients.
- Roblox also layers OpenID Connect on top of OAuth for user identity claims.
- Users must be 13+ to authorize apps.
- Developers must be ID verified to register and publish OAuth apps.

## Rules

- Use authorization code flow for Roblox OAuth integrations.
- Treat browser and mobile apps as public clients.
- Never expose a confidential client secret to public code or public storage.
- Add `openid` if the app needs an ID token.
- Add `profile` only when the app needs richer user profile claims, and only alongside `openid`.

## Patterns

### Client classification

- Confidential client: backend-capable app that can securely hold secrets.
- Public client: mobile or browser app that cannot safely hold secrets.

### OAuth plus OIDC

- OAuth access token: authorizes Open Cloud API access.
- ID token: proves identity and carries claims; it does not grant API access.

### High-level flow

```text
Register app
-> send user to /oauth/v1/authorize
-> receive code on redirect
-> exchange code at /oauth/v1/token
-> call APIs with bearer access token
-> refresh or revoke later as needed
```

## Examples

- A creator authorizes a third-party dashboard to manage a universe without sharing Roblox credentials.
- A mobile companion app uses PKCE and asks only for `openid` plus the one API scope it actually needs.
