# Cloud Guides

## Key Concepts

- The cloud guides are workflow-oriented walkthroughs for common Open Cloud tasks.
- Guides usually include end-to-end request examples, required IDs, and resource-specific setup steps.
- They are useful when the question is about a concrete operational flow rather than a single endpoint lookup.
- Common guide areas include assets, inventory, configs, place publishing, universe messaging, notifications, instance APIs, and secrets usage.

## Rules

- Start with a guide when the task describes a real workflow, not just one endpoint.
- Extract only the request mechanics, required identifiers, and sequence of calls that matter to the current integration.
- Use guides to discover the right API surface, then verify exact scopes, limits, and schemas in the reference or JSON artifacts.
- Do not let a guide pull the answer into out-of-scope data-architecture or OAuth-implementation detail.

## Patterns

### Use guides as workflow maps

- usage-place-publishing.md: publish places or place versions from automation.
- usage-messaging.md: send universe messages from the web.
- usage-assets.md: asset-related cloud workflows.
- inventory.md: user inventory retrieval flows.
- configs.md: config repository draft and publish workflows.
- instance.md: poll long-running instance operations.
- experience-notifications.md: notification sending workflows.

### Extract the minimum implementation facts

From a guide, pull:

- Required resource IDs.
- Endpoint sequence.
- Request body shape.
- Polling or pagination behavior.
- Any scope or permission note that affects the caller.

## Examples

### Publishing automation

- Use the place publishing guide to confirm the correct universe ID, place ID, upload endpoint, and response handling.

### Message broadcast tool

- Use the messaging guide to confirm the universe message endpoint, payload, and expected response behavior before coding the script.

### In-experience secret-backed call

- Use the secrets-related guide material together with the HttpService docs when an API key must live inside Roblox-managed secrets.
