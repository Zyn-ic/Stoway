# Cloud Reference JSON Files

## Key Concepts

- The local cloud reference artifacts live under sources/creator-docs/reference/cloud/.
- README.md explains that the reference site is rendered from these JSON files.
- openapi.json is the full cross-product OpenAPI document.
- cloud.docs.json is a doc-oriented cloud spec with Roblox extensions and resource metadata used by the documentation system.
- Service-specific files such as universes-api/v1.json, assets/v1.json, and developer-products-api/v1.json narrow the surface to one domain.

## Rules

- Start with openapi.json when you need a global search across all Open Cloud endpoints.
- Use cloud.docs.json when doc metadata such as categories or resource naming is useful.
- Use service-specific v1.json files when you want the smallest artifact for a targeted tool or script.
- Read extension metadata such as scopes, engine usability, and rate limits from the JSON rather than guessing.
- If two artifacts disagree, verify against the published reference because these files are generated and evolving.

## Patterns

### Search by operation ID

```text
rg -n operationId sources/creator-docs/reference/cloud
```

- Use this to locate the authoritative path, request body, and response shape.

### Search for engine-usable endpoints

```text
rg -n apiKeyWithHttpService sources/creator-docs/reference/cloud
```

- Use this when planning an in-experience integration.

### Search for scope or rate-limit metadata

```text
rg -n x-roblox-scopes sources/creator-docs/reference/cloud
rg -n x-roblox-rate-limits sources/creator-docs/reference/cloud
```

- Use this to confirm required permissions and quota envelopes before implementation.

## Examples

### Narrow artifact selection

- Use universes-api/v1.json when the task is only universe or place publishing automation.

### Full-surface inspection

- Use openapi.json when building a generalized tool, Postman collection, or generated client.

### Doc-metadata inspection

- Use cloud.docs.json when you need category labels, resource names, or richer documentation-oriented annotations.
