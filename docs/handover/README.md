# Enzily technical handoff - 17 November 2026

The PDF and checklist are prepared for the receiving technical team. Paths in the
workspace guide refer to the Enzily directory containing all five repositories.
No credentials, customer database dumps or signing private keys are included.

Published source baselines on 16 November 2026:

- Player application: `2052e10` (10.0.32 / build 40, Trix and native symbol fixes).
- Standalone Qaed website: `123b321` (new-game Trix signs and collapsible history).
- API: `5d18cb11` (historical synthetic campaign evidence and tools added; runtime
  code remains the previously deployed score-sheet implementation).
- Admin: `6a103fe`.
- Company website: `24ace02`.

This documentation commit follows those source baselines. Source publication is
complete; receiving-team acceptance and the documented concurrency/shared-IP
follow-up items remain to be assigned and verified.

The original release-40 manifest records that the binary was built before source
publication. Its original artifact hashes and signing evidence remain valid;
pushing the source and documentation does not update an installed app.
