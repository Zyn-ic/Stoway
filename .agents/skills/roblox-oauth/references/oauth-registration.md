# OAuth Registration

## Key Concepts

- Roblox app registration happens in Creator Dashboard under OAuth 2.0 Apps.
- Registration creates a client ID and a client secret.
- The client secret is shown once; after that, it must be regenerated if lost.
- Apps begin in private mode with a limit of 10 unique users.
- Public distribution requires app review and publication.
- Redirect URLs, scopes, and public-facing app metadata are part of app configuration.

## Rules

- Register apps only for individual accounts or groups you own.
- Store the secret immediately and securely after app creation.
- Request the minimum set of scopes required by the app.
- Keep the scope set aligned to a single app category under Roblox policy.
- Use exact redirect URLs that match one of the allowed forms.
- Reauthorize users after adding or changing scopes.

## Patterns

### Redirect URL rules

- Allowed:
  - `https://example.com`
  - `http://localhost:3000`
  - `https://localhost:3000`
  - custom schemes such as `my-app://callback`
- Limits:
  - up to 10 redirect URLs
  - each URL up to 256 characters

### Registration workflow

```text
Create App
-> capture client ID and secret
-> add description and links
-> add scopes
-> add redirect URLs
-> test in private mode
-> submit for review when ready
```

### Edit behavior

- Changing general info or redirect URLs does not force reauthorization.
- Changing scopes requires new authorization for the new permission set.

## Examples

- Local web app: add `http://localhost:3000/oauth/callback`.
- Production site plus staging site: use two separate HTTPS redirects.
- Public app iteration: clone the public app into a private app for safe testing before resubmission.
