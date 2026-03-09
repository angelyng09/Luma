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

2. Product Constraints to Enforce

- VoiceOver-first: every primary action must be accessible with linear focus navigation and clear spoken labels.
- Minimal gestures: single tap/select, double tap activate, simple vertical adjust where needed; no gesture-only hidden controls.
- Usable without looking: each key screen must support full interaction via spoken prompts, haptics, and predictable focus order.
- No QR dependence: place entry via search, nearby detection, recent list, or voice command.
- Rule-based first: deterministic parsing/scoring/categorization; AI optional in later phase.
- Realistic shipping: use Apple-native frameworks and simple backend patterns.

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
- Offline read cache for last viewed places + pending review queue.

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
  - URLSession + async/await
  - Local persistence: SQLite via GRDB or Core Data (choose one; GRDB is simpler for explicit schema control)
  - Background sync for queued feedback via BGTaskScheduler (best-effort)

4.2 Backend (Simple, Maintainable)
- API: REST (FastAPI/Node/Go; pick team’s strongest stack)
- DB: PostgreSQL
- Jobs/cron:
  - Recompute place confidence snapshots every 15 minutes
  - Recompute summary bullets every 15 minutes
- Auth: anonymous device token for MVP + optional signed-in account later
- Observability: request logs, error logging, basic metric counters

5. Data Model (MVP Tables)

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
- `user_id` (uuid/hashed device id)
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

6.2 General Scoring Rules (Detailed, MVP Baseline)
- Objective:
  - Produce one deterministic `accessibility_score` (0-100) per place that reflects recent accessibility conditions more than old reports.
- Scope of data included:
  - Include only reviews with `status=active` and `confirmed=true`.
  - Use `event_time` as the time reference for freshness (not `created_at`).
  - Ignore `flagged`, `hidden`, and `removed` reviews from scoring and summary generation.

- Step A: Per-review weight calculation
  - For each eligible review `r`:
    - `hours_since_review = max(0, hours_between(now_utc, r.event_time))`
    - `recency_weight = exp(-hours_since_review / 168)`  // 168h = 7 days decay constant
    - `credibility_weight = 1.0` for MVP (dynamic reputation weighting intentionally disabled)
    - `review_weight = recency_weight * credibility_weight`
  - Interpretation:
    - A very recent review has weight close to 1.0.
    - Older reviews are still considered but decay smoothly toward 0.

- Step B: Weighted average on rating scale (1-5)
  - `weighted_sum = sum(r.rating * review_weight)`
  - `weight_total = sum(review_weight)`
  - If `weight_total > 0`:
    - `weighted_rating_1_to_5 = weighted_sum / weight_total`
  - If `weight_total == 0` (no eligible reviews):
    - Set `weighted_rating_1_to_5 = 3.0` (neutral fallback for stable UI output).

- Step C: Normalize to 0-100 score
  - `raw_score = ((weighted_rating_1_to_5 - 1.0) / 4.0) * 100.0`
  - `normalized_score = clamp(round(raw_score), 0, 100)`

- Step D: Low-evidence penalty (general trust rule)
  - `review_count_30d = count(active and confirmed reviews where event_time >= now_utc - 30 days)`
  - If `review_count_30d < 3`:
    - `accessibility_score = min(normalized_score, 65)`
    - Mark place as `low_confidence` for UI messaging.
  - Else:
    - `accessibility_score = normalized_score`

- Step E: Summary extraction from the same weighted set
  - Build “works well” from highest weighted items where `rating in [4,5]`.
  - Build “common issues” from highest weighted items where `rating in [1,2]`.
  - Keep top 2 items per side for concise VoiceOver output.

- Step F: Snapshot persistence and freshness
  - Persist to `place_scores_snapshot`:
    - `accessibility_score`
    - `review_count_30d`
    - `low_confidence`
    - `top_positive_json`
    - `top_negative_json`
    - `last_review_at`
    - `last_venue_update_at`
    - `computed_at`
  - Recompute trigger policy:
    - Event-driven recompute after review confirm/save.
    - Scheduled recompute every 15 minutes as consistency backstop.

- Determinism requirements:
  - Same input dataset and same `now_utc` reference must always produce the same output.
  - No generative model influence is allowed in scoring path for MVP.

6.3 Summary Generation (Template-Based)
- No generative AI.
- Build top bullets from highest weighted active signals:
  - “works well” from highest weighted ratings (4-5)
  - “common issues” from lowest weighted ratings (1-2)
- Spoken summary format:
  - “Accessibility confidence 72 out of 100. Working well: elevator availability, helpful staff. Common issues: restroom wayfinding, crowding.”

7. API Contract (MVP Endpoints) (backend-to-app agreement for MVP)

7.0 Shared Contract Rules
- Base path: `/v1`
- Content type: `application/json; charset=utf-8`
- Timestamp format: RFC3339 UTC (example: `2026-03-09T18:30:00Z`)
- Authentication headers:
  - `Authorization: Bearer <anonymous_device_token>`
  - `X-Role: user | venue_maintenance | community_management | admin`
- Idempotency for write operations:
  - Header: `Idempotency-Key: <device_id+place_id+event_time+raw_text_hash>`
  - Required on `POST/PATCH` endpoints that mutate data.
- Pagination:
  - Cursor-based for list endpoints.
  - Query params: `limit` (default 20, max 100), `cursor` (opaque token).
  - Response `meta`: `{ "next_cursor": "..." | null }`
- Standard error envelope:
  - `{ "error": { "code": "<STRING_CODE>", "message": "<human readable>", "details": { ... } } }`
- Standard HTTP status usage:
  - `200` success read/update, `201` created, `400` validation error, `401` unauthorized, `403` forbidden, `404` not found, `409` conflict, `422` semantic validation, `429` rate limited, `500` server error.

7.1 `GET /v1/places/search`
- Query params:
  - `q` (string, required, 2-80 chars)
  - `lat` (float, optional)
  - `lng` (float, optional)
  - `radius_m` (int, optional, default 2000, min 100, max 5000)
  - `sort` (enum, optional): relevance, distance, score (default relevance)
  - `limit` (int, optional), `cursor` (string, optional)
- Response `200`:
  - `data.items[]`:
    - `place_id` (uuid)
    - `name` (string)
    - `distance_m` (int, nullable when lat/lng absent)
    - `accessibility_score` (int 0-100)
    - `low_confidence` (bool)
    - `review_count_30d` (int)
    - `last_review_at` (timestamp, nullable)
  - `meta.next_cursor` (string|null)
- Errors:
  - `400 INVALID_QUERY`, `401 UNAUTHORIZED`, `429 RATE_LIMITED`, `500 INTERNAL_ERROR`

7.2 `GET /v1/places/{place_id}/summary`
- Path params:
  - `place_id` (uuid, required)
- Response `200`:
  - `data`:
    - `place_id` (uuid)
    - `name` (string)
    - `accessibility_score` (int 0-100)
    - `low_confidence` (bool)
    - `review_count_30d` (int)
    - `top_positive` (array<string>, max 2)
    - `top_negative` (array<string>, max 2)
    - `last_review_at` (timestamp, nullable)
    - `last_venue_update_at` (timestamp, nullable)
    - `computed_at` (timestamp)
- Errors:
  - `400 INVALID_PLACE_ID`, `401 UNAUTHORIZED`, `404 PLACE_NOT_FOUND`, `500 INTERNAL_ERROR`

7.3 `GET /v1/places/nearby`
- Query params:
  - `lat` (float, required)
  - `lng` (float, required)
  - `radius_m` (int, optional, default 500, min 100, max 2000)
  - `limit` (int, optional), `cursor` (string, optional)
- Response `200`:
  - `data.items[]`: same shape as search result item
  - `meta.next_cursor` (string|null)
- Errors:
  - `400 INVALID_COORDINATES`, `401 UNAUTHORIZED`, `429 RATE_LIMITED`, `500 INTERNAL_ERROR`

7.4 `GET /v1/places/{place_id}/reviews`
- Query params:
  - `limit` (int, optional, default 20, max 100)
  - `cursor` (string, optional)
  - `status` (enum, optional): active, flagged, hidden, removed, all (default active)
  - `signal_type` (enum, optional)
  - `from` (timestamp, optional)
  - `to` (timestamp, optional)
- Permission rule:
  - `user` role can request only `status=active`.
  - moderation roles can request all statuses.
- Response `200`:
  - `data.items[]`:
    - `review_id` (uuid)
    - `place_id` (uuid)
    - `raw_text` (string)
    - `signal_type` (enum)
    - `rating` (int 1-5)
    - `source` (enum: voice|text)
    - `event_time` (timestamp)
    - `status` (enum)
    - `confirmed` (bool)
    - `created_at` (timestamp)
  - `meta.next_cursor` (string|null)
- Errors:
  - `400 INVALID_FILTER`, `401 UNAUTHORIZED`, `403 FORBIDDEN_STATUS_SCOPE`, `404 PLACE_NOT_FOUND`, `500 INTERNAL_ERROR`

7.5 `POST /v1/reviews`
- Headers:
  - `Authorization`, `X-Role`, `Idempotency-Key` (required)
- Body:
  - `place_id` (uuid, required)
  - `raw_text` (string, required, 1-2000 chars)
  - `event_time` (timestamp, required)
  - `source` (enum, required): voice, text
- Behavior:
  - Server parses signal type + suggested score.
  - Persists review with `confirmed=false` and `status=active`.
- Response `201`:
  - `data`:
    - `review_id` (uuid)
    - `place_id` (uuid)
    - `signal_type` (enum)
    - `suggested_rating` (int 1-5)
    - `confirmed` (bool=false)
    - `status` (enum=active)
    - `created_at` (timestamp)
- Errors:
  - `400 INVALID_BODY`, `401 UNAUTHORIZED`, `404 PLACE_NOT_FOUND`, `409 DUPLICATE_IDEMPOTENCY_KEY`, `422 REVIEW_TOO_LONG_OR_INVALID_TIME`, `500 INTERNAL_ERROR`

7.6 `POST /v1/reviews/{id}/confirm`
- Headers:
  - `Authorization`, `X-Role`, `Idempotency-Key` (required)
- Body:
  - `confirmed` (bool, required)
  - `raw_text` (string, optional correction if user edited)
  - `signal_type` (enum, optional correction)
  - `rating` (int 1-5, optional correction)
- Behavior:
  - If `confirmed=true`, set `confirmed=true`, set `confirmed_at`, and trigger recompute job for place snapshot.
  - If `confirmed=false`, keep review unconfirmed (or delete by policy) and allow client resubmission path.
- Response `200`:
  - `data`:
    - `review_id` (uuid)
    - `confirmed` (bool)
    - `status` (enum)
    - `recompute_enqueued` (bool)
- Errors:
  - `400 INVALID_CONFIRM_PAYLOAD`, `401 UNAUTHORIZED`, `403 FORBIDDEN`, `404 REVIEW_NOT_FOUND`, `409 REVIEW_ALREADY_CONFIRMED`, `500 INTERNAL_ERROR`

7.7 `PATCH /v1/places/{place_id}/venue-status` (FR-10 support)
- Permission:
  - Allowed roles: `venue_maintenance`, `admin`
- Headers:
  - `Authorization`, `X-Role`, `Idempotency-Key` (required)
- Body:
  - `elevator_status` (enum): available, unavailable, unknown
  - `restroom_access` (enum): normal, limited, unavailable, unknown
  - `temporary_issue_flag` (bool)
  - `temporary_issue_note` (string, optional, max 500)
  - `event_time` (timestamp, required)
- Behavior:
  - Persist to `venue_status_updates`.
  - Trigger summary recompute.
- Response `200`:
  - `data`:
    - `update_id` (uuid)
    - `place_id` (uuid)
    - `last_venue_update_at` (timestamp)
    - `recompute_enqueued` (bool)
- Errors:
  - `400 INVALID_VENUE_STATUS`, `401 UNAUTHORIZED`, `403 FORBIDDEN_ROLE`, `404 PLACE_NOT_FOUND`, `500 INTERNAL_ERROR`

7.8 `POST /v1/reviews/{id}/moderation` (FR-11 support)
- Permission:
  - Allowed roles: `community_management`, `admin`
- Headers:
  - `Authorization`, `X-Role`, `Idempotency-Key` (required)
- Body:
  - `action` (enum, required): flag, hide, restore, remove
  - `reason` (string, optional, max 500)
- Behavior:
  - Write action record to `review_moderation_actions`.
  - Apply review status mapping:
    - `flag` -> `flagged`
    - `hide` -> `hidden`
    - `restore` -> `active`
    - `remove` -> `removed`
  - Trigger summary recompute when final status affects scoring visibility.
- Response `200`:
  - `data`:
    - `review_id` (uuid)
    - `new_status` (enum)
    - `action_id` (uuid)
    - `recompute_enqueued` (bool)
- Errors:
  - `400 INVALID_MODERATION_ACTION`, `401 UNAUTHORIZED`, `403 FORBIDDEN_ROLE`, `404 REVIEW_NOT_FOUND`, `409 INVALID_STATUS_TRANSITION`, `500 INTERNAL_ERROR`

8. iOS App Structure (Engineer-Ready)

8.1 Modules
- `AppCore` (routing, DI container, shared models)
- `Features/OnboardingTutorial`
- `Features/Search`
- `Features/PlaceDetail`
- `Features/Nearby`
- `Features/SubmitReview`
- `Data/RemoteAPI`
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
  - Failure: queue offline and announce “Review queued”.
- Nearby:
  - Loading: announce “Finding nearby places”.
  - Success: list sorted by distance with full VoiceOver labels.
  - Failure: if location denied, show shortcut to manual search.

9. iOS Local DB Schema (Cache + Outbox)

9.0 `app_settings`
- `key` (text, pk)
- `value` (text)
- Required keys:
  - `tutorial_completed` = `true|false`
  - `tutorial_last_played_at` = ISO8601 timestamp

9.1 `cached_place_summaries`
- `place_id` (text, pk)
- `place_name` (text)
- `accessibility_score` (int)
- `top_positive_json` (text)
- `top_negative_json` (text)
- `last_review_at` (text/ISO8601)
- `review_count_30d` (int)
- `cached_at` (text/ISO8601)

9.2 `cached_place_reviews`
- `id` (text, pk)
- `place_id` (text, indexed)
- `rating` (int 1-5)
- `raw_text` (text)
- `event_time` (text/ISO8601)
- `cached_at` (text/ISO8601)

9.3 `review_outbox`
- `local_id` (text, pk)
- `place_id` (text, indexed)
- `raw_text` (text)
- `rating` (int 1-5, nullable if server derives it)
- `event_time` (text/ISO8601)
- `attempt_count` (int default 0)
- `next_retry_at` (text/ISO8601)
- `created_at` (text/ISO8601)
- `status` (text): pending, sending, failed

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

- Cache:
  - Last 20 place summaries
  - Last 50 recent reviews viewed
- Outbox:
  - Unsent review queue with retry backoff (30s, 2m, 10m, 30m, 2h)
- If offline:
  - User can still read cached summary
  - User can submit review locally; app announces “Review queued, will send when online”
- Timeout rules:
  - Search/summary/reviews reads timeout at 10 seconds.
  - Review submit timeout at 15 seconds, then move item to outbox.
- Duplicate handling:
  - Client sends idempotency key: `device_id + place_id + event_time + raw_text_hash`.
  - Server returns existing review when same key was already processed.
- Retry stop condition:
  - After 10 failed attempts, mark outbox item `failed` and show “Retry now” action.

12. Security and Privacy (MVP-Level)

- No precise movement history stored beyond current request.
- Hash device identifier before storage.
- Encrypt transport with HTTPS only.
- Basic abuse protection:
  - rate limit review submissions per user/hour
  - profanity/spam keyword filter

13. Build Plan (5 Weeks, Realistic)

Week 1 (Feb 29-Mar 6): Foundations
- Feb 29: Kickoff, repo/module setup, define branch and ticket ownership.
- Mar 1: Implement API client skeleton, local DB bootstrap, base navigation shell.
- Mar 3: Add shared accessibility helpers + spoken announcement utility.
- Mar 5: Integration check across Home flow with VoiceOver focus order pass.
- Mar 6: Week 1 sign-off.
- Done when: app boots, navigates, and VoiceOver focus order is correct on Home.

Week 2 (Mar 7-Mar 13): Search + Place Summary
- Mar 7: Start `/places/search` API integration and result model wiring.
- Mar 9: Implement `/places/{id}/summary` integration and snapshot mapping.
- Mar 11: Complete Search screen + Place Detail UI with spoken summary behavior.
- Mar 13: End-to-end demo and acceptance check.
- Done when: user can search and hear usable summary end-to-end.

Week 3 (Mar 14-Mar 20): Feedback Pipeline
- Mar 14: Start speech capture and transcript preview flow.
- Mar 16: Implement POST review + confirm/edit UX.
- Mar 18: Complete server rule-based parser/tagger and review persistence wiring.
- Mar 20: Timing validation (voice review submission under 30 seconds).
- Done when: user can submit a voice review in under 30 seconds.

Week 4 (Mar 21-Mar 27): Nearby + Recency Feed
- Mar 21: Implement CoreLocation nearby list pipeline.
- Mar 23: Add recent reviews view with recency metadata.
- Mar 25: Implement recency phrasing (“2 hours ago”) and spoken announcements.
- Mar 27: On-site flow validation (no QR, minimal taps).
- Done when: on-site flow works with no QR and minimal taps.

Week 5 (Mar 28-Apr 3): Scoring + Snapshot Jobs + Hardening
- Mar 28: Implement score computation job + summary bullet generation.
- Mar 30: Add low-evidence cap and “low confidence” messaging.
- Apr 1: Accessibility QA with VoiceOver users/testers.
- Apr 2: Offline queue tests, error handling, analytics events.
- Apr 3: Release readiness review + TestFlight go/no-go.
- Done when: accessibility score updates reflect new reviews within 15 minutes and release checklist passes with stable TestFlight build.

14. QA Checklist (Must Pass Before MVP Release)

- VoiceOver-only journey succeeds for:
  - Search place
  - Hear summary
  - Submit feedback
  - Check nearby reviews
- No QR flow required anywhere.
- No crash during permission denial (location/microphone/speech).
- Offline review queue survives app restart.
- Confidence score and summary fields always present (fallback text if low data).

15. Post-MVP (Optional AI Later)

- AI-assisted clustering only after rule-based baseline is stable.
- AI moderation assist for conflict detection and duplicate merging.
- Personalized filtering by mobility profile.

16. Immediate Implementation Start (First Tickets)

- Ticket 1: Create SwiftUI app shell + accessibility utilities.
- Ticket 2: Implement place search API + Search screen.
- Ticket 3: Implement place summary API + Detail screen with spoken summary.
- Ticket 4: Implement speech-to-text review submission + confirmation.
- Ticket 5: Build backend rule parser + review persistence.
- Ticket 6: Add nearby places screen using CoreLocation foreground updates.
- Ticket 7: Add local cache + outbox queue + retry worker.
