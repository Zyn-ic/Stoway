# Roadmap & Known Limitations

Near-term, in rough order:

- **Persistence.** State is per session; the `createPlayer` / `removePlayer`
  hook points exist, no saver ships.
- **Client Add\*/UpdateMetadata policy.** The trust model calls this out:
  client-originated item/mutation payloads reach routes unfiltered.
- **Failure-correction rate limits.** Only sync requests are throttled.
- **Moonwave API extraction.** The facade reference is hand-maintained;
  revisit when it hurts.

Next: [Glossary](glossary.md).
