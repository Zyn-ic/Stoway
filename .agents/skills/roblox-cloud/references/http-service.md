# HttpService

## Key Concepts

- HttpService can call third-party web services and a subset of Open Cloud endpoints from inside Roblox experiences.
- HTTP requests must be enabled in Experience Settings before requests can be sent.
- Open Cloud requests from HttpService still require an API key.
- For Open Cloud calls, the API key must be provided from Roblox Secrets via HttpService:GetSecret(...).
- RequestAsync is the practical method when you need custom method, headers, or JSON body handling.

## Rules

- Verify that the target endpoint is supported for engine use before writing the request.
- Only x-api-key and content-type headers are allowed for Open Cloud calls through HttpService.
- The x-api-key header value must be a Secret.
- Use HTTPS only.
- Do not include .. in Roblox-domain URL path parameters.
- Handle send failures with pcall and response failures through Success, StatusCode, StatusMessage, and Body.

## Patterns

### Supported request shape

```lua
local HttpService = game:GetService('HttpService')

local response = HttpService:RequestAsync({
    Url = 'https://apis.roblox.com/cloud/v2/groups/123',
    Method = 'GET',
    Headers = {
        ['x-api-key'] = HttpService:GetSecret('APIKey'),
    },
})
```

### JSON body request

```lua
local response = HttpService:RequestAsync({
    Url = 'https://apis.roblox.com/cloud/v2/groups/123/memberships/456',
    Method = 'PATCH',
    Headers = {
        ['Content-Type'] = 'application/json',
        ['x-api-key'] = HttpService:GetSecret('APIKey'),
    },
    Body = HttpService:JSONEncode({
        role = 'groups/123/roles/789',
    }),
})
```

### Rate-limit model

- Each server has a limit of 2500 Open Cloud requests per minute.
- Endpoint-specific limits per API key owner still apply on top of that.
- Open Cloud requests do not consume the separate general 500 HTTP requests per minute limit for other HTTP traffic.

## Examples

### Supported in-experience use

- Update a group membership or read a supported universe, place, group, or storage endpoint from a server script.

### Failure handling

- Wrap the send in pcall, then branch on response.Success and response.StatusCode for retry or fallback logic.

### Scope check before code

- Before using HttpService, inspect the reference JSON or docs for the endpoint's x-roblox-engine-usability and required scopes.
