Luma iOS MVP Technical Route (SwiftUI, VoiceOver-First, Build-Ready)

1. Goal and Non-Goals

Goal (MVP)
- Help visually impaired users decide if a place is manageable before they go.
- Provide recent, spoken community signals on-site without QR codes.
- Capture voice feedback and convert it to structured reviews with simple rule-based logic.

Non-Goals (MVP)
- No indoor turn-by-turn navigation.
- No custom mapping stack.
- No AI-heavy moderation or generative pipeline in v1.
- No venue enterprise dashboard in v1.
- No backend service development or cloud sync in MVP.

2. Product Constraints to Enforce

- VoiceOver-first: every primary action must be accessible with linear focus navigation and clear spoken labels.
- Minimal gestures: single tap/select, double tap activate, simple vertical adjust where needed; no gesture-only hidden controls.
- Usable without looking: each key screen must support full interaction via spoken prompts, haptics, and predictable focus order.
- No QR dependence: place entry via search, nearby detection, recent list, or voice command.
- Rule-based first: deterministic parsing/scoring/categorization; AI optional in later phase.
- Realistic shipping: use Apple-native frameworks with on-device data and no backend development in MVP.

3. MVP Feature Set (Ship This First)

- First-launch audio tutorial (voice-guided walkthrough, replayable from Home).
- Place Search (text + speech input).
- Place Detail summary:
  - Accessibility Confidence Score (0-100)
  - Top 2 “works well”
  - Top 2 “common problems”
  - Last update recency
- Nearby/On-site status via GPS proximity (no geofencing daemon required for v1).
- Submit Feedback via speech-to-text + rule-based auto-tagging + confirmation step.
- Recent reviews list prioritized by recency and credibility.
- On-device persistence for place summaries, reviews, and draft recovery.

4. System Architecture (Concrete)

4.1 iOS App (SwiftUI + Native APIs)
- UI: SwiftUI
- Accessibility:
  - VoiceOver labels/hints/traits
  - `@AccessibilityFocusState` for predictable focus movement
  - `UIAccessibility.post(notification:.announcement, ...)` for spoken transitions
- Speech:
  - iOS Speech framework for dictation-to-text
  - AVSpeechSynthesizer for optional in-app TTS prompts
- Location:
  - CoreLocation standard updates (foreground) for nearby place suggestions
- Data:
  - Local persistence: SQLite via GRDB or Core Data (choose one; GRDB is simpler for explicit schema control)
  - No remote API calls in MVP; all reads/writes happen on-device
  - Background maintenance tasks (best-effort) for local cleanup/recompute

4.2 On-Device Data Layer (MVP Decision)
- No backend service development for MVP.
- Source of truth: local SQLite database stored on the phone.
- All scoring, summary generation, moderation actions, and venue-status updates run in-app.
- Account-and-password authentication is handled in-app, and role-based permissions are enforced locally.
- Data export/sync is out of MVP scope.

5. Data Model (MVP Local Tables)

5.1 `places` (masterlist)
- `id` (uuid, pk)
- `name` (text, indexed)
- `lat` (double coordinates)
- `lng` (double coordinates)
- `category` (text) // hospital, mall, transit, etc.
- `city` (text)
- `created_at`, `updated_at` (timestamps)

5.2 `reviews`
- `id` (uuid, pk)
- `place_id` (uuid, fk -> places)
- `user_id` (local account id)
- `raw_text` (text)
- `signal_type` (enum): entrance_access, pathway_clarity, stairs_condition, elevator_status, escalator_status, restroom_access, seating_availability, staff_helpfulness, security_helpfulness, queue_manageability, crowding_level, noise_level, lighting_glare, obstacle_hazards, temporary_disruptions, other
- `rating` (int 1-5) // single rating: 1 very poor, 5 very good
- `source` (enum): voice, text
- `event_time` (timestamp) // when user says it happened
- `created_at` (timestamp)
- `confirmed` (bool default false)
- `confirmed_at` (timestamp, nullable)
- `status` (enum): active, flagged, hidden, removed
- `moderation_reason` (text, nullable)
- `last_moderated_at` (timestamp, nullable)

5.3 `user_reputation` (MVP decision: enabled in schema, fixed at 1.0)
- `user_id` (pk)
- `score` (float 0.5-1.5 default 1.0) //1.0 = normal influence, 1.5 = higher trust, 0.5 = lower trust
- `reviews_count` (int)
- `agreement_rate` (float 0-1) // how well their reviews align with others
- `updated_at`

5.4 `place_scores_snapshot` (summary table for each place)
- `place_id` (pk)
- `accessibility_score` (int 0-100) // overall score
- `review_count_30d` (int)
- `low_confidence` (bool)
- `top_positive_json` (jsonb array of strings) //pros about the place
- `top_negative_json` (jsonb array of strings) //common issues with the place
- `last_review_at` (timestamp)
- `last_venue_update_at` (timestamp, nullable)
- `computed_at` (timestamp)

5.5 `venue_status_updates` (role feature support: FR-10)
- `id` (uuid, pk)
- `place_id` (uuid, fk -> places, indexed)
- `actor_user_id` (uuid/hashed device id)
- `actor_role` (enum): venue_maintenance, community_management, admin
- `elevator_status` (enum): available, unavailable, unknown
- `restroom_access` (enum): normal, limited, unavailable, unknown
- `temporary_issue_flag` (bool)
- `temporary_issue_note` (text, nullable)
- `event_time` (timestamp)
- `created_at` (timestamp)
- `status` (enum): active, superseded

5.6 `review_moderation_actions` (role feature support: FR-11)
- `id` (uuid, pk)
- `review_id` (uuid, fk -> reviews, indexed)
- `place_id` (uuid, fk -> places, indexed)
- `actor_user_id` (uuid/hashed device id)
- `actor_role` (enum): community_management, admin
- `action` (enum): flag, hide, restore, remove
- `reason` (text, nullable)
- `created_at` (timestamp)

6. Rule-Based Logic Layer (Deterministic)

6.1 Feedback Auto-Tagging (No LLM)
- Dictionary + regex approach:
  - Facility keywords: elevator, lift, restroom, toilet, entrance, escalator, security desk
  - Rating keywords:
    - very negative (“broken”, “unsafe”, “blocked”) -> rating 1
    - negative (“hard to find”, “crowded”, “loud”) -> rating 2
    - neutral/unclear -> rating 3
    - positive (“helpful”, “available”, “easy”) -> rating 4
    - very positive (“excellent”, “always available”, “very helpful”) -> rating 5

6.2 Dimension-Weighted Scoring Rules (Directional MVP Guideline)
- Objective:
  - Produce one deterministic `accessibility_score` (0-100) per place using a weighted multi-dimension model.
  - Keep this as a practical guideline for MVP tuning, not a fixed academic model.
- Scope of data included:
  - Include only reviews with `status=active` and `confirmed=true`.
  - Include latest active venue status updates.
  - Use `event_time` as the time reference for freshness (not `created_at`).
  - Ignore `flagged`, `hidden`, and `removed` reviews from scoring and summary generation.

- Scoring dimensions and suggested weights:
  - Entrance accessibility: `15%`
  - Route clarity: `15%`
  - Vertical mobility availability (elevator/escalator/alternatives): `12%`
  - Restroom accessibility: `10%`
  - Obstacles and hazards: `12%`
  - Staff assistance availability: `10%`
  - Crowd and queue manageability: `10%`
  - Environmental perceivability (noise/broadcast/glare): `8%`
  - Temporary disruption impact (service stop/closure/breakdown): `8%`

- Step A: Build each dimension rating (`1-5`)
  - For each dimension `d`, gather relevant evidence within its active lookback window.
  - Evidence source:
    - review signals mapped to this dimension
    - venue status updates mapped to this dimension
  - For each evidence item `e`:
    - `hours_since_event = max(0, hours_between(now_utc, e.event_time))`
    - For permanent accessibility dimensions, use slower decay:
      - `recency_weight = exp(-hours_since_event / 2160)`  // 90-day decay constant
    - For temporary disruption impact, use faster decay:
      - `recency_weight = exp(-hours_since_event / 240)`  // 10-day decay constant (within 7-14 day target)
    - `evidence_weight = recency_weight`
  - Compute:
    - `dimension_rating_d = weighted_avg(e.rating_1_to_5, evidence_weight)`
  - Fallback:
    - if dimension has no recent evidence in its lookback window, set `dimension_rating_d = 3.0` and mark dimension as `uncertain`.

- Step B: Compute final score (`0-100`)
  - Since weights sum to `100`, use either equivalent form:
    - `raw_score = sum(dimension_rating_d * weight_percent_d) / 5`
    - `raw_score = weighted_average_rating_1_to_5 * 20`
  - Critical-structure safety cap:
    - if `entrance_accessibility_rating <= 2`, then `raw_score = min(raw_score, 60)`.
  - `accessibility_score = clamp(round(raw_score), 0, 100)`  // rounded to nearest integer

- Step C: Low confidence rule
  - `review_count_90d = count(active and confirmed reviews where event_time >= now_utc - 90 days)`
  - `review_count_total = count(all active and confirmed reviews)`
  - If `review_count_90d < 3` OR `review_count_total < 5`:
    - mark place as `low_confidence = true`.
  - Else:
    - set `low_confidence = false`.

- Step D: Summary extraction from the same evidence set
  - Build “works well” from high-rated evidence (`rating in [4,5]`) with strongest weights.
  - Build “common issues” from low-rated evidence (`rating in [1,2]`) with strongest weights.
  - Keep top 2 items per side for concise VoiceOver output.

- Step E: Snapshot persistence and freshness
  - Persist to `place_scores_snapshot`:
    - `accessibility_score`
    - `review_count_30d`
    - `review_count_90d`
    - `review_count_total`
    - `dimension_uncertain_json`
    - `low_confidence`
    - `top_positive_json`
    - `top_negative_json`
    - `last_review_at`
    - `last_venue_update_at`
    - `computed_at`
  - Recompute trigger policy:
    - Event-driven recompute after review confirm/save and venue-status updates.
    - Lightweight consistency pass on app launch and when returning to foreground.

- Determinism requirements:
  - Same input dataset and same `now_utc` reference must always produce the same output.
  - No generative model influence is allowed in scoring path for MVP.

6.3 Summary Generation (Template-Based)
- No generative AI.
- Build top bullets from highest weighted active evidence aligned to scoring dimensions:
  - “works well” from highest weighted ratings (4-5)
  - “common issues” from lowest weighted ratings (1-2)
- Spoken summary format:
  - “Accessibility confidence 72 out of 100. Working well: elevator availability, helpful staff. Common issues: restroom wayfinding, crowding.”

7. Local Data Service Contract (In-App, No Backend)

7.0 Shared Contract Rules
- Execution boundary:
  - All operations are in-process Swift services (`LocalRepository`, `RuleEngine`, `PermissionGuard`).
  - No HTTP endpoints, no server deployment, no remote request/response cycle.
- Timestamp format: RFC3339 UTC (example: `2026-03-11T18:30:00Z`).
- Authentication and authorization:
  - User signs in with account + password in-app.
  - Current role is read from local account profile: `user | venue_maintenance | community_management | admin`.
- Write consistency:
  - Every mutation runs in a single SQLite transaction.
  - On transaction failure, operation is rolled back and no partial state is committed.
- Pagination:
  - Offset-based for local lists.
  - Params: `limit` (default 20, max 100), `offset` (default 0).
- Standard local error envelope:
  - `{ "error": { "code": "<STRING_CODE>", "message": "<human readable>", "details": { ... } } }`

7.1 `searchPlaces(query, lat, lng, radiusM, sort, limit, offset)`
- Inputs:
  - `query` (string, required, 2-80 chars)
  - `lat` (float, optional)
  - `lng` (float, optional)
  - `radiusM` (int, optional, default 2000, min 100, max 5000)
  - `sort` (enum, optional): relevance, distance, score (default relevance)
  - `limit`, `offset` (optional)
- Output:
  - `items[]` with `place_id`, `name`, `distance_m`, `accessibility_score`, `low_confidence`, `review_count_30d`, `last_review_at`
- Errors:
  - `INVALID_QUERY`, `DB_READ_FAILED`

7.2 `getPlaceSummary(placeId)`
- Inputs:
  - `placeId` (uuid, required)
- Output:
  - `place_id`, `name`, `accessibility_score`, `low_confidence`, `review_count_30d`, `top_positive[]`, `top_negative[]`, `last_review_at`, `last_venue_update_at`, `computed_at`
- Errors:
  - `INVALID_PLACE_ID`, `PLACE_NOT_FOUND`, `DB_READ_FAILED`

7.3 `getNearbyPlaces(lat, lng, radiusM, limit, offset)`
- Inputs:
  - `lat` (float, required)
  - `lng` (float, required)
  - `radiusM` (int, optional, default 500, min 100, max 2000)
  - `limit`, `offset` (optional)
- Output:
  - `items[]` same shape as `searchPlaces`
- Errors:
  - `INVALID_COORDINATES`, `DB_READ_FAILED`

7.4 `listReviews(placeId, status, signalType, from, to, limit, offset)`
- Inputs:
  - `placeId` (uuid, required)
  - `status` (enum, optional): active, flagged, hidden, removed, all (default active)
  - `signalType` (enum, optional)
  - `from`, `to` (timestamp, optional)
  - `limit`, `offset` (optional)
- Permission rule:
  - `user` role can request only `status=active`.
  - Moderation roles can request all statuses.
- Output:
  - `items[]` with `review_id`, `place_id`, `raw_text`, `signal_type`, `rating`, `source`, `event_time`, `status`, `confirmed`, `created_at`
- Errors:
  - `INVALID_FILTER`, `FORBIDDEN_STATUS_SCOPE`, `PLACE_NOT_FOUND`, `DB_READ_FAILED`

7.5 `createReview(placeId, rawText, eventTime, source)`
- Inputs:
  - `placeId` (uuid, required)
  - `rawText` (string, required, 1-2000 chars)
  - `eventTime` (timestamp, required)
  - `source` (enum, required): voice, text
- Behavior:
  - In-app rule engine parses signal type + suggested rating.
  - Persist review with `confirmed=false` and `status=active`.
- Output:
  - `review_id`, `place_id`, `signal_type`, `suggested_rating`, `confirmed`, `status`, `created_at`
- Errors:
  - `INVALID_BODY`, `PLACE_NOT_FOUND`, `REVIEW_TOO_LONG_OR_INVALID_TIME`, `DB_WRITE_FAILED`

7.6 `confirmReview(reviewId, confirmed, rawText?, signalType?, rating?)`
- Inputs:
  - `reviewId` (uuid, required)
  - `confirmed` (bool, required)
  - Optional corrections: `rawText`, `signalType`, `rating`
- Behavior:
  - If `confirmed=true`, set `confirmed=true`, set `confirmed_at`, then recompute place snapshot immediately in-app.
  - If `confirmed=false`, keep unconfirmed (or delete by policy) and allow user resubmission.
- Output:
  - `review_id`, `confirmed`, `status`, `recompute_completed`
- Errors:
  - `INVALID_CONFIRM_PAYLOAD`, `FORBIDDEN`, `REVIEW_NOT_FOUND`, `REVIEW_ALREADY_CONFIRMED`, `DB_WRITE_FAILED`

7.7 `updateVenueStatus(placeId, elevatorStatus, restroomAccess, temporaryIssueFlag, temporaryIssueNote, eventTime)` (FR-10 support)
- Permission:
  - Allowed roles: `venue_maintenance`, `admin`
- Behavior:
  - Persist to `venue_status_updates`.
  - Trigger in-app summary recompute.
- Output:
  - `update_id`, `place_id`, `last_venue_update_at`, `recompute_completed`
- Errors:
  - `INVALID_VENUE_STATUS`, `FORBIDDEN_ROLE`, `PLACE_NOT_FOUND`, `DB_WRITE_FAILED`

7.8 `moderateReview(reviewId, action, reason?)` (FR-11 support)
- Permission:
  - Allowed roles: `community_management`, `admin`
- Behavior:
  - Write action record to `review_moderation_actions`.
  - Apply review status mapping:
    - `flag` -> `flagged`
    - `hide` -> `hidden`
    - `restore` -> `active`
    - `remove` -> `removed`
  - Trigger in-app summary recompute when status affects scoring visibility.
- Output:
  - `review_id`, `new_status`, `action_id`, `recompute_completed`
- Errors:
  - `INVALID_MODERATION_ACTION`, `FORBIDDEN_ROLE`, `REVIEW_NOT_FOUND`, `INVALID_STATUS_TRANSITION`, `DB_WRITE_FAILED`

8. iOS App Structure (Engineer-Ready)

8.1 Modules
- `AppCore` (routing, DI container, shared models)
- `Features/OnboardingTutorial`
- `Features/Search`
- `Features/PlaceDetail`
- `Features/Nearby`
- `Features/SubmitReview`
- `Data/LocalRepository`
- `Data/LocalStore`
- `Domain/RulePresentation` (format spoken summaries, recency phrasing)

8.2 Primary Screens
- First-Launch Tutorial:
  - Auto-opens on first app launch before Home
  - Controls: “Play/Pause”, “Repeat section”, “Skip tutorial”, “Finish”
  - Completion state is saved; user can replay from Home
- Launch/Home:
  - Primary actions as large accessible buttons:
    - “Search place”
    - “Nearby places”
    - “Review current place”
    - “Play tutorial again”
- Search screen:
  - Text field + microphone button
  - Results list (each row announces name, distance, confidence)
- Place detail:
  - Spoken summary on appear (user setting controlled)
  - Explicit sections with headings for VoiceOver rotor
- Feedback capture:
  - Record speech -> transcript preview
  - “Confirm review” / “Edit text” / “Cancel”
- Nearby screen:
  - Foreground location update + list within 500m

8.3 Accessibility Acceptance Rules (Per Screen)
- All actionable elements have `accessibilityLabel`, `accessibilityHint`, `accessibilitySortPriority`.
- No action requires drag path precision.
- First VoiceOver focus lands on screen title.
- Screen transitions announce completion state.
- Dynamic type up to accessibility sizes without clipped controls.

8.4 VoiceOver Behavior Spec Per Screen
- First-Launch Tutorial:
  - Initial focus: title “Luma audio tutorial”
  - Announcement on appear: “Welcome to Luma tutorial. Use play, repeat, skip, or finish.”
- Home:
  - Initial focus: screen title “Luma Home”
  - Announcement on appear: “Home. Choose search, nearby, or review current place.”
- Search:
  - Initial focus: search input field
  - Announcement on results loaded: “Found X places.”
- Place Detail:
  - Initial focus: place name heading
  - Announcement on appear: “Accessibility score X out of 100. Swipe right for details.”
- Review Capture:
  - Initial focus: “Start voice review” button
  - Announcement after transcript ready: “Transcript ready. Confirm or edit.”
- Nearby:
  - Initial focus: “Nearby places” heading
  - Announcement on location update: “X nearby places within 500 meters.”

8.5 Screen-by-Screen Acceptance Criteria
- First-Launch Tutorial:
  - Loading: tutorial audio loads and announces “Tutorial ready”.
  - Success: user taps Finish and lands on Home.
  - Failure: if audio fails, show spoken fallback text and allow Skip/Continue.
- Home:
  - Loading: primary buttons disabled until startup checks finish.
  - Success: all 3 primary actions are reachable and spoken correctly.
  - Failure: show retry action and announce failure.
- Search:
  - Loading: announce “Searching”.
  - Success: result rows announce place name, distance, and accessibility score.
  - Failure: announce “Search failed. Try again.”
- Place Detail:
  - Loading: announce “Loading place summary”.
  - Success: score, top positives, top issues, and last review time are present.
  - Failure: show cached summary if available, else announce no data.
- Review Capture:
  - Loading: announce recording/transcribing state changes.
  - Success: submit review and announce “Review submitted”.
  - Failure: save draft locally and announce “Review saved locally. Please try again.”
- Nearby:
  - Loading: announce “Finding nearby places”.
  - Success: list sorted by distance with full VoiceOver labels.
  - Failure: if location denied, show shortcut to manual search.

9. iOS Local DB Schema (Primary Store, On-Device)

9.0 `app_settings`
- `key` (text, pk)
- `value` (text)
- Required keys:
  - `tutorial_completed` = `true|false`
  - `tutorial_last_played_at` = ISO8601 timestamp

9.1 `accounts`
- `account_id` (text, pk)
- `username` (text, unique)
- `password_hash` (text)
- `role` (text): user, venue_maintenance, community_management, admin
- `created_at` (text/ISO8601)
- `last_login_at` (text/ISO8601, nullable)

9.2 `places`
- `place_id` (text, pk)
- `place_name` (text, indexed)
- `lat` (real)
- `lng` (real)
- `category` (text)
- `city` (text)
- `updated_at` (text/ISO8601)

9.3 `place_scores_snapshot`
- `place_id` (text, pk)
- `accessibility_score` (int)
- `top_positive_json` (text)
- `top_negative_json` (text)
- `last_review_at` (text/ISO8601)
- `review_count_30d` (int)
- `last_venue_update_at` (text/ISO8601, nullable)
- `computed_at` (text/ISO8601)

9.4 `reviews`
- `id` (text, pk)
- `place_id` (text, indexed)
- `rating` (int 1-5)
- `raw_text` (text)
- `signal_type` (text)
- `source` (text): voice, text
- `confirmed` (bool)
- `status` (text): active, flagged, hidden, removed
- `event_time` (text/ISO8601)
- `created_at` (text/ISO8601)
- `updated_at` (text/ISO8601)

9.5 `venue_status_updates`
- `id` (text, pk)
- `place_id` (text, indexed)
- `actor_account_id` (text)
- `actor_role` (text)
- `elevator_status` (text)
- `restroom_access` (text)
- `temporary_issue_flag` (bool)
- `temporary_issue_note` (text, nullable)
- `event_time` (text/ISO8601)
- `created_at` (text/ISO8601)
- `status` (text): active, superseded

9.6 `review_moderation_actions`
- `id` (text, pk)
- `review_id` (text, indexed)
- `place_id` (text, indexed)
- `actor_account_id` (text)
- `actor_role` (text)
- `action` (text): flag, hide, restore, remove
- `reason` (text, nullable)
- `created_at` (text/ISO8601)

10. iOS Permissions Flow (Microphone, Speech, Location)
- Microphone denied:
  - Show “Open Settings” and fallback to typed review entry.
  - VoiceOver announcement: “Microphone access is off.”
- Speech recognition denied:
  - Disable voice transcription and keep typed review entry available.
  - VoiceOver announcement: “Speech recognition is off.”
- Location denied:
  - Nearby screen shows manual search and recent places.
  - VoiceOver announcement: “Location access is off. Use search instead.”
- Core rule:
  - Search and place detail must work even if all permissions are denied.

11. Error and Retry Rules

- Read behavior:
  - All lists and summaries read from local SQLite; no network dependency.
- Write behavior:
  - On write failure, preserve user input as local draft and show “Retry now”.
- DB lock handling:
  - Retry write transaction with backoff (100ms, 300ms, 800ms, 2s), then fail gracefully.
- Duplicate handling:
  - Use unique constraint on `(place_id, event_time, raw_text_hash)` for review inserts.
- Recovery:
  - On app relaunch, restore unfinished draft review and pending local edits.

12. Security and Privacy (MVP-Level)

- No precise movement history stored beyond current request.
- Hash device identifier before storage when device-level identity is required.
- Store credential secrets in Keychain; store only password hashes in SQLite.
- Enable iOS Data Protection for local database files.
- Basic abuse protection:
  - local submission throttling per account/session
  - profanity/spam keyword filter

13. Build Plan (5 Weeks, Realistic)

Week 1 (Feb 29-Mar 6): Foundations
- Feb 29: Kickoff, repo/module setup, define branch and ticket ownership.
- Mar 1: Implement local repository skeleton, local DB bootstrap, base navigation shell.
- Mar 3: Add shared accessibility helpers + spoken announcement utility.
- Mar 5: Integration check across Home flow with VoiceOver focus order pass.
- Mar 6: Week 1 sign-off.
- Done when: app boots, navigates, and VoiceOver focus order is correct on Home.

Week 2 (Mar 7-Mar 13): Search + Place Summary
- Mar 7: Implement local place search query pipeline and result model wiring.
- Mar 9: Implement local place summary query and snapshot mapping.
- Mar 11: Complete Search screen + Place Detail UI with spoken summary behavior.
- Mar 13: End-to-end demo and acceptance check.
- Done when: user can search and hear usable summary end-to-end.

Week 3 (Mar 14-Mar 20): Feedback Pipeline
- Mar 14: Start speech capture and transcript preview flow.
- Mar 16: Implement local review create + confirm/edit UX.
- Mar 18: Complete in-app rule-based parser/tagger and local review persistence wiring.
- Mar 20: Timing validation (voice review submission under 30 seconds).
- Done when: user can submit a voice review in under 30 seconds.

Week 4 (Mar 21-Mar 27): Nearby + Recency Feed
- Mar 21: Implement CoreLocation nearby list pipeline.
- Mar 23: Add recent reviews view with recency metadata.
- Mar 25: Implement recency phrasing (“2 hours ago”) and spoken announcements.
- Mar 27: On-site flow validation (no QR, minimal taps).
- Done when: on-site flow works with no QR and minimal taps.

Week 5 (Mar 28-Apr 3): Scoring + Snapshot Recompute + Hardening
- Mar 28: Implement in-app score computation + summary bullet generation.
- Mar 30: Add low-confidence thresholds and structural-failure score cap messaging.
- Apr 1: Accessibility QA with VoiceOver users/testers.
- Apr 2: Local persistence recovery tests, error handling, analytics events.
- Apr 3: Release readiness review + TestFlight go/no-go.
- Done when: accessibility score updates reflect confirmed reviews immediately after local commit and release checklist passes with stable TestFlight build.

14. QA Checklist (Must Pass Before MVP Release)

- VoiceOver-only journey succeeds for:
  - Search place
  - Hear summary
  - Submit feedback
  - Check nearby reviews
- No QR flow required anywhere.
- No crash during permission denial (location/microphone/speech).
- Local review drafts and edits survive app restart.
- Confidence score and summary fields always present (fallback text if low data).

15. Post-MVP (Optional AI Later)

- AI-assisted clustering only after rule-based baseline is stable.
- AI moderation assist for conflict detection and duplicate merging.
- Personalized filtering by mobility profile.

16. Immediate Implementation Start (First Tickets)

- Ticket 1: Create SwiftUI app shell + accessibility utilities.
- Ticket 2: Implement local place search service + Search screen.
- Ticket 3: Implement local place summary service + Detail screen with spoken summary.
- Ticket 4: Implement speech-to-text review submission + confirmation.
- Ticket 5: Build in-app rule parser + local review persistence.
- Ticket 6: Add nearby places screen using CoreLocation foreground updates.
- Ticket 7: Add local DB recovery flow + write-retry worker for transient DB lock.
