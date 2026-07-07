# Webhooks Documentation

## Key Concepts

- Roblox webhooks push event data to a third-party URL or custom HTTPS endpoint when a supported event occurs.
- Current supported trigger families include subscription events, compliance right-to-erasure events, and commerce order events.
- Webhooks can target Discord, Slack, or a custom endpoint, but Roblox only fully supports Discord and Slack integrations.
- Each payload includes fixed fields: NotificationId, EventType, EventTime, and an EventPayload object.
- Delivery is retry-based, and duplicates are possible.

## Rules

- The webhook URL must be publicly reachable over HTTPS, accept POST, and return a 2XX response within 5 seconds.
- Verify roblox-signature when a secret is configured.
- Deduplicate events by NotificationId.
- Treat webhook handling as idempotent because retries and duplicates can occur.
- Return success quickly and move slower processing to a queue or worker.
- Enforce a replay window by checking the signature timestamp against current time.

## Patterns

### Receiver flow

1. Receive POST payload.
2. Parse roblox-signature.
3. Rebuild <timestamp>.<raw body>.
4. Compute HMAC-SHA256 with the shared secret and compare signatures.
5. Reject stale timestamps.
6. Check whether NotificationId was already processed.
7. Enqueue or process the event.
8. Return 2XX quickly.

### Signature format

```text
t=<timestamp>,v1=<signature>
```

- If no secret is configured, only the timestamp is present.

### Payload contract

```text
NotificationId: string
EventType: RightToErasureRequest
EventTime: 2023-12-30T16:24:24.2118874Z
EventPayload:
  UserId: 1
  GameIds: 1234, 2345
```

## Examples

### Duplicate-safe handling

- If the same NotificationId arrives twice, process it once and acknowledge the duplicate without re-running side effects.

### Fast acknowledgment

- Return a 2XX immediately after signature verification and dedupe checks, then do slower work off the request path.

### Test flow

- Use the Creator Dashboard test action and validate receipt of SampleNotification before turning on production triggers.
