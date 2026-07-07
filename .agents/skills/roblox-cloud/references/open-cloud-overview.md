# Open Cloud Overview

## Key Concepts

- Roblox Open Cloud exposes Roblox resources through HTTP APIs under https://apis.roblox.com.
- Open Cloud is intended for external automation such as CLIs, CI jobs, web apps, bots, and operational tooling.
- Open Cloud also supports webhooks and a subset of endpoints through in-experience HttpService.
- Roblox recommends Open Cloud endpoints that support API keys or OAuth 2.0 over legacy cookie-authenticated APIs.
- For this skill, API keys are the default authentication choice for non-user automation.

## Rules

- Prefer stable Open Cloud endpoints over legacy cookie-authenticated endpoints.
- Choose API keys for server-to-server, team-owned, or experience-owned automation that does not require user consent.
- If the integration needs user-delegated access or OAuth tokens, stop and switch to roblox-oauth.
- Keep the discussion on HTTP integration and request mechanics, not gameplay or engine architecture.

## Patterns

### Triage a cloud integration

1. Identify the caller: backend, CLI, CI, webhook receiver, or HttpService.
2. Find the endpoint and confirm the base URL and path template.
3. Confirm scopes, rate limits, and whether the endpoint works with HttpService.
4. Choose API key auth for non-user automation.
5. Implement retries, pagination, or polling if the endpoint requires them.

### Basic request shape

```text
GET https://apis.roblox.com/cloud/v2/...path...
x-api-key: <api key>
```

- Add Content-Type: application/json when the request includes a JSON body.
- Use exact IDs in path parameters rather than guessing resource names.

## Examples

### External automation

- A deployment script publishes places or updates universe settings through Open Cloud.

### Operational bot

- A webhook worker receives a Roblox event and then calls an Open Cloud endpoint to continue an automation flow.

### In-experience request

- A server script uses HttpService to call a supported Open Cloud endpoint with an API key stored in Secrets.
