# API Patterns, Errors, Types, Scopes, And Rate Limits

## Key Concepts

- Open Cloud requests combine a base URL, path template, and optional query parameters.
- Many list endpoints paginate with maxPageSize, pageToken, and nextPageToken.
- Some endpoints return Operation resources that must be polled until done is true.
- Patch-style updates may use updateMask to limit which fields change.
- Open Cloud payloads use JSON plus special formats such as RFC 3339 timestamps, duration strings, base64 bytes, field masks, and decimal objects.
- Scopes define what the caller can do; rate limits define how often the caller can do it.

## Rules

- Insert all path parameters exactly and do not mutate the rest of the query while paginating.
- Send Content-Type and a valid JSON body for endpoints that create or update resources.
- Confirm the endpoint's required scopes before implementation.
- Read x-ratelimit-limit, x-ratelimit-remaining, and x-ratelimit-reset when available.
- Handle HTTP 429 with retry-after if present; otherwise use exponential backoff.
- Treat INVALID_ARGUMENT as a request-shape problem first and PERMISSION_DENIED or INSUFFICIENT_SCOPE as an auth or scope problem first.

## Patterns

### Pagination loop

```text
GET ...?maxPageSize=100
-> read nextPageToken
GET ...?maxPageSize=100&pageToken=<token>
```

- Keep every other query parameter identical between pages.
- Stop when nextPageToken is empty or absent.

### Long-running operation polling

```text
POST or PATCH ... -> Operation
GET <operation path>
GET <operation path> after backoff
```

- Poll using the returned operation path.
- Back off between polls instead of hammering the endpoint.

### Partial update with field masks

```text
PATCH ...?updateMask=foo.bar,baz
```

- Include only the fields you intend to change.
- Align the JSON body with the mask.

### Error triage

- 400 INVALID_ARGUMENT: bad ID, bad filter, bad header, or malformed body.
- 403 PERMISSION_DENIED or INSUFFICIENT_SCOPE: missing scope or no access to the target resource.
- 404 NOT_FOUND: wrong resource path or resource does not exist.
- 409 ABORTED: conflict state.
- 429 RESOURCE_EXHAUSTED: quota or rate limit exceeded.
- 5xx: transient or server-side failure; retry with backoff if safe.

## Examples

### Stable pagination

- Good: keep filter and maxPageSize unchanged while advancing pageToken.
- Bad: change filter between pages and reuse an old token.

### Duration and timestamp handling

```text
startTime: 2023-07-05T12:34:56Z
duration: 3s
```

### Rate-limit-aware retry

- Read retry-after on 429.
- If it is absent, retry after 1s, 2s, 4s, and so on with a cap.
