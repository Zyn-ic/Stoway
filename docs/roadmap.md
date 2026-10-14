# Roadmap & Known Limitations

Near-term, in rough order:

- **Persistence.** State is per session; the `createPlayer` / `removePlayer`
  hook points exist, no saver ships.
- **Client Add\*/UpdateMetadata policy.** The trust model calls this out:
  client-originated item/mutation payloads reach routes unfiltered.
- **Failure-correction rate limits.** Only sync requests are throttled.
- **Tests folder in the shipped project.** `StowayClientV3/Tests/` maps into
  `StarterPlayerScripts`, so the observer harnesses run for every player in a
  built place. Strip per the [builds protocol](builds.md) before release.
- **Moonwave API extraction.** The facade reference is hand-maintained;
  revisit when it hurts.

Next: [Glossary](glossary.md).
