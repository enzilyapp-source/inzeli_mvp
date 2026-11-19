# untitled

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Permanent challenge frames — 19 November 2026

Open **Profile → Challenges** for the new reward collection. `lib/pages/challenge_rewards_page.dart` displays server progress and applies unlocked frames; `lib/challenge_rewards.dart` parses the cached snapshot. `lib/widgets/reward_avatar_frame.dart` displays the transparent 5×3 sprite sheet in `lib/assets/rewards/avatar_frames_v1.png`. Stable IDs and sprite slots are registered in `lib/widgets/challenge_rank_visuals.dart`.

The approved rank identities use the existing milestones: Beginner/عليمي 5 (bronze), Good/زين 10 (silver), Professional/محترف 15 (gold), Legendary/أسطوري 20 (diamond), Best/أحسن واحد 30 (crown). Each tier has a permanent frame and banner; the earlier reward_rank_* IDs remain owned and render their original artwork. Game challenges require 10 combined card-game wins, 5 wins each for backgammon/chess/football/racket games/basketball/billiards/bowling, and 50 total wins for the moon frame. Wins are lifetime recorded results, including existing matches. Losses and manual scorekeeper rounds do not count as wins.

The API owns eligibility and permanent `UserItem` entitlements. No seasonal reset deletes rewards or changes the selected frame. `AppState` caches ownership across restarts and offline refresh failures; switching accounts clears that cache, and equipping requires server acceptance. A fresh device recovers rewards from the server. The original theme challenges remain available separately.

Deploy the matching API changes before shipping this app. No schema migration or reset is needed; locked/inactive reward items cannot be bought. The old app continues to work, but the new frame artwork requires the new client. This feature does not auto-equip a prize, charge pearls, or change leaderboard rules.

Tests: `flutter test test/challenge_rewards_test.dart test/profile_dashboard_test.dart`, `flutter analyze`. See API `src/store/challenge-rewards.ts` for rules; keep IDs/slots synchronized when adding new art.


### Heritage collection

Twelve additional permanent win rewards use `heritage_frames_v1.png` (4×3 cells). Stable slots 15–26 follow the classic 0–14 slots, so existing frames and cached choices keep their artwork. The Challenges page lists these under **تحديات تراثية**. General wins unlock engraved gold (3), dhow (10), Kuwait towers (25), swords (30), and falcon (75). Popular-game wins unlock ghutra (5) and tent (10); sports wins unlock the fort (15); card-game wins unlock coffee (20) and heritage cards (30); backgammon/chess each unlock their heritage frame at 15 wins. All counts are lifetime server-recorded wins. No new migration or reset is required.


### Profile editor and paired rank rewards

`lib/pages/profile_appearance_editor.dart` replaces the old horizontal theme picker with an owned-only grid, photo upload/removal, live draft preview, unlocked rank banners and plain background colors. Saving sends frame/themeId and banner/cardId together to PATCH /users/me; failed saves or dismissed drafts do not change the stored selections. A selected banner paints in both the Profile hero and the shared home header. `lib/widgets/rank_identity.dart` is the single display mapping for the approved names, metals, thresholds, medal painter and scalable banner artwork. `rank_levels_sheet.dart` shows all five tiers with their point thresholds, medal, frame and banner. Current-rank badges use the new medal in place of the controller icon.

Versioned IDs reward_tier_{beginner,good,professional,legend,best} select frame slots 1–5 from the existing art. Matching reward_banner_* items are StoreKind.card; no new schema field is needed. Beginner frame/banner are starter entitlements even before a first match. Higher tiers use server-recorded badge history and unlock in pairs. Old cosmetics stay compatible; legacy rank challenges are hidden from the main rank-reward list but their owned frames remain in the editor. Deploy API before the new client. Tests in test/profile_appearance_test.dart cover the approved mapping, one-request saves, rejected saves, owned-only choices, draft dismissal and responsive editor layout.
