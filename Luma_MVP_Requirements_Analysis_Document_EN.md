# Luma MVP Requirements Analysis Document

## 1. Document Information
- Document Name: Luma MVP Requirements Analysis Document
- Scope: iOS MVP (SwiftUI, VoiceOver first)
- Document Version: v1.0
- Updated On: 2026-03-09
- Status: Review Draft

## 2. Background and Problem Definition
The core issue visually impaired users face in real-world travel is not "can't find a place," but "can't tell before leaving whether the place is currently safe and manageable independently." Existing public information usually stays at generic dimensions such as address, business hours, and overall rating, and cannot answer highly relevant questions like whether the elevator is working, whether pathways are blocked, or whether the site is too crowded. As a result, users often make decisions with insufficient information, increasing time cost, psychological stress, and on-site risk.

From the user task journey, the main pain points are concentrated at four breakpoints:
- Pre-decision breakpoint: Lack of recent, trustworthy, and comparable accessibility status information, making it hard to quickly decide "go or not go."
- On-arrival breakpoint: On-site conditions change quickly (temporary construction, facility failures, queue congestion), static information becomes invalid, and users lack real-time reference.
- Interaction breakpoint: Many products depend on visual operations or complex gestures in key steps, which are not VoiceOver-friendly and reduce usability.
- Feedback breakpoint: After users find issues, contribution cost is high and structure is low, making information hard to accumulate into reusable community signals.

Major gaps in existing solutions:
- General maps/review platforms have shallow coverage of accessibility fields and weak timeliness.
- Information presentation is designed for "reading," not for "listening" and linear operation.
- Community feedback lacks a unified structure, making it difficult to form computable place-level confidence.

Based on the issues above, the positioning of Luma MVP is an "accessibility decision-and-feedback closed loop layer for visually impaired users," focused on high-frequency rigid needs instead of broad feature completeness. Its value loop is:
1. Low-barrier input: Users can quickly submit on-site feedback by voice, reducing contribution friction.
2. Rule-based processing: Convert natural-language feedback into structured signals and scores to ensure explainable, reproducible results.
3. Voice-consumable output: Broadcast place status as concise summaries so users can understand quickly without visual attention.
4. Actionable decisions: Provide three key information types, "score + recent issues + update time," to directly support go/no-go decisions.

Therefore, Luma MVP is not a traditional "navigation product" or "review product." It is a lightweight decision infrastructure built around "pre-trip judgment + on-arrival confirmation + immediate feedback return." This boundary helps control complexity in the MVP phase, keep VoiceOver usability first, and deliver verifiable real value within a limited timeline.

## 3. Product Goals and Success Criteria

### 3.1 MVP Goals
- Help users quickly judge whether a place is manageable before departure.
- Help users get recent community signals after arrival, without relying on QR codes.
- Enable users to quickly submit feedback by voice to generate structured community data.

### 3.2 Non-Goals
- No indoor turn-by-turn navigation.
- No self-built map infrastructure.
- No heavy AI moderation or generative capabilities.
- No merchant-side operations console.
- No real account registration/login authentication or server-side session management.

### 3.3 Success Metrics (recommended MVP evaluation criteria)
- Task completion rate: VoiceOver-only main flow completion rate >= 90%.
- Decision efficiency: From opening the app to receiving the place summary, P50 <= 20 seconds.
- Feedback efficiency: From start of recording to submission completion, P50 <= 30 seconds.
- Stability: Crash rate in core flows < 0.5%.
- Data freshness: New confirmed feedback is reflected in place summaries within 15 minutes.

## 4. Target Users and Roles

### 4.1 Product Roles (MVP demo identities)
- Visually impaired/low-vision user account.
- Venue maintenance account.
- Community management account.

### 4.2 Account Implementation Strategy (MVP)
- All three account types use local demo identities (preset accounts + local role switching).
- No real login integration, password system, or user-facing account registration flows.
- Core flows for the visually impaired/low-vision role must be truly usable (search, summary, nearby, feedback).
- Venue maintenance and community management roles are used for review demos of permissions and workflows, not as live operations systems.

### 4.3 Role Permission Boundaries (MVP)
- Visually impaired/low-vision user account: Can use tutorial, search, place details, nearby places, voice feedback, and recent reviews.
- Venue maintenance account: Can maintain venue status fields in shared system data (for example facility availability and temporary issue markers).
- Community management account: Can perform content management actions in shared system data (flag, hide, restore community feedback).

### 4.4 Usage Environment Characteristics
- High noise, unstable network, one-handed operation, and inability to continuously stare at the screen.

### 4.5 Role Permission Matrix (MVP)
Notes:
- `✅` means visible and executable.
- `Read-only` means visible but not executable for changes.
- `❌` means hidden by default or inaccessible.

| Feature/Page | Key Action | Visually impaired/low-vision user | Venue maintenance | Community management | Notes |
|---|---|---|---|---|---|
| Role switching | Switch current demo identity | ✅ | ✅ | ✅ | Takes effect immediately in local session, no login authentication triggered |
| First-time tutorial | Play/Pause/Skip/Complete | ✅ | ✅ | ✅ | All three roles can demo accessibility flow |
| Home | Enter Search/Nearby/Feedback/Tutorial | ✅ | ✅ | ✅ | Same home entry points; downstream permissions are role-controlled |
| Place search | Search places by text/voice | ✅ | ✅ | ✅ | Unified backend data with local cache fallback |
| Place details | View score, pros/cons, update time | ✅ | ✅ | ✅ | Readable by default for all roles |
| Recent reviews list | Browse recent reviews | ✅ | ✅ | ✅ | Readable by default for all roles |
| Voice feedback | Create and save feedback | ✅ | ✅ | ❌ | Community management role does not participate in normal feedback submission |
| Nearby places | Use location to view nearby places | ✅ | ✅ | ✅ | Affected by location permission; fallback path when denied |
| Venue status maintenance | Modify facility status/temporary issue marker | ❌ | ✅ | Read-only | Only venue maintenance role can save changes |
| Community content management | Flag/Hide/Restore feedback | ❌ | Read-only | ✅ | Only community management role can execute management actions |
| Local data management | Refresh from server/Clear cache/Retry outbox | Read-only | ✅ | ✅ | For demo efficiency, maintenance and management roles may execute |

## 5. Core User Scenarios

### Scenario A: Pre-trip accessibility assessment
The user finds a place through search (text or voice), listens to summary information (score, strengths, issues, update time), and decides whether to go.

### Scenario B: Quick confirmation after arrival
The user uses "Nearby Places" to check relevant venues at the current location and quickly obtains recent accessibility status.

### Scenario C: On-site feedback return
The user submits on-site observations via voice. The system auto-parses and provides confirmation. After success, data is submitted to backend services (or queued locally when offline), then reflected in shared summaries.

## 6. Scope Definition (MVP)

### 6.1 In Scope
- First-launch voice tutorial (replayable).
- Place search (text + voice input).
- Place detail summary (score, positive/negative key points, update time).
- Nearby places list (foreground location).
- Voice feedback submission (transcription, auto-tagging, confirmation).
- Recent reviews list (prioritized by recency and confidence).
- Backend API integration with local cache/outbox persistence.
- Three local demo roles, role switching, and permission toggles.

### 6.2 Out of Scope
- Indoor navigation and route guidance.
- QR code as the only entry point.
- Enterprise management backend.
- Complex AI reasoning, generation, and automatic moderation pipeline.
- Real account system (registration, login, password recovery, server authentication, cross-device identity sync).

## 7. Functional Requirements List (by Priority)

## P0 (Must-have)

### FR-00 Local demo accounts and role switching
- Provide 3 preset demo accounts: visually impaired/low-vision user, venue maintenance, community management.
- Support local in-app role switching (no network dependency).
- After role switch, page entry points and executable actions change in real time by permissions.

Acceptance Criteria:
- All three roles can be switched successfully and take effect in the current session.
- Under VoiceOver, role-switch entry is focusable, readable, and operable.
- No role triggers real login/authentication flow.

### FR-01 First-launch tutorial
- On first app open, automatically enter tutorial.
- Tutorial provides play, pause, repeat, skip, and complete.
- Tutorial completion state can be persisted and replayed from home.

Acceptance Criteria:
- First launch automatically enters tutorial.
- After tapping complete, enter home and record completion state.
- If audio fails, provide a readable text fallback.

### FR-02 Home main accessible entry points
- Home provides four main entries: Search Places, Nearby Places, Review Current Place, Replay Tutorial.
- Entry points must be large buttons, semantically clear, and reachable in linear focus order.

Acceptance Criteria:
- Under VoiceOver, all four entries can be focused in order and executed.
- Initial focus lands on the "Luma Home" title.

### FR-03 Place search
- Support text-input search.
- Support voice input and text conversion for search.
- Search results display name, distance, and confidence score.
- Search data source is backend search API, with local cache fallback when unavailable.

Acceptance Criteria:
- During search, announce "Searching".
- On success, announce "Found X places".
- On failure, announce "Search failed. Try again.".

### FR-04 Place summary details
- Display accessibility score (0-100).
- Display Top 2 positive signals and Top 2 negative signals.
- Display latest update time and review count in the last 30 days.
- Summary is read from backend-computed snapshot with local cache fallback.

Acceptance Criteria:
- Page must include four categories: score, strengths, issues, update time.
- Offline: show cache first; if no cache, provide readable fallback copy.

### FR-05 Voice feedback submission
- Support audio recording transcription into text.
- System auto-parses signal type and suggested score.
- User can confirm, edit, or cancel before submission.

Acceptance Criteria:
- After transcription completes, announce "Transcript ready. Confirm or edit.".
- On successful submit, announce "Review submitted".
- After save, place summary page reflects data changes caused by this feedback.

### FR-06 Nearby places
- Use foreground location to get place list within 500 meters.
- List is sorted by ascending distance.
- If location is unavailable, provide manual search alternative.

Acceptance Criteria:
- On entering page, announce "Finding nearby places".
- After location update, announce "X nearby places within 500 meters.".
- If location permission is denied, prompt "Location access is off. Use search instead.".

### FR-07 Offline cache, outbox, and persistence
- Cache recently viewed place summaries and reviews.
- After voice feedback confirmation, submit to backend; if submission fails, queue in local outbox for retry.
- Local history and states can be restored after app restart.

Acceptance Criteria:
- Offline does not block reading cached summaries/details and queueing feedback.
- After restart, recently viewed history and queued feedback remain readable/retryable.
- Outbox retry and failure states are visible and actionable.

## P1 (Should-have)

### FR-08 Recent reviews list
- Place details show recent reviews, sorted by recency and confidence.

Acceptance Criteria:
- Show latest 20 entries by default.
- Each entry can read out score, content, and timestamp.

### FR-09 Permission-denial usability fallback
- If microphone, speech recognition, or location is denied, core flow still runs.

Acceptance Criteria:
- If microphone is denied, user can switch to text input.
- If speech recognition is denied, submission flow is not blocked.
- If location is denied, nearby page provides an executable alternative path.

### FR-10 Venue maintenance role demo capability
- Venue maintenance account can modify venue-status-related fields through backend APIs.
- After changes, place detail summary reflects backend-updated status and timestamp.

Acceptance Criteria:
- Venue maintenance role can complete the loop: "modify status -> save -> visible on frontend".
- Non-venue-maintenance roles cannot access this maintenance entry.

### FR-11 Community management role demo capability
- Community management account can flag, hide, and restore community feedback through backend APIs.
- Management actions must keep operation timestamp records.

Acceptance Criteria:
- Community management role can complete flag/hide/restore actions and take effect immediately.
- Non-community-management roles cannot access management action entry points.

## 8. Accessibility Requirements (Hard Constraints)
- All interactive elements must provide `accessibilityLabel` and `accessibilityHint`.
- Key elements must define clear focus order and `accessibilitySortPriority`.
- The first focus on every page must be fixed on the page title.
- Key page state transitions must include voice announcements (loading, success, failure).
- No key capability may depend only on complex gestures.
- Dynamic Type must support accessibility font sizes without clipping.

## 9. Business Rule Requirements

### 9.1 Rule Parsing
- Use keyword dictionary + regular expressions for signal classification.
- Use sentiment keyword mapping for score suggestion (1-5).
- Parsing results must be explainable and reproducible.

### 9.2 Score Calculation
- Use time-decay weighting to calculate place score.
- MVP uses fixed credibility weight 1.0.
- When reviews in the last 30 days are fewer than 3, cap score at 65 and display "low confidence".

### 9.3 Summary Generation
- Use template composition, not generative models.
- Positive highlights come from high-score, high-weight signals.
- Negative highlights come from low-score, high-weight signals.

## 10. Non-Functional Requirements

### 10.1 Performance
- Search API response + render time P95 <= 1.5 seconds on stable network.
- Summary fetch (or cache fallback render) time P95 <= 1.5 seconds.
- First-screen interactive time (cold start) recommended <= 2.5 seconds.

### 10.2 Reliability
- Core read flows must degrade gracefully under network loss using cached data.
- Feedback submission must support offline outbox + retry until success or terminal failure.
- If local database errors occur, provide recoverable degraded prompts and rebuild capability.

### 10.3 Security and Privacy
- Do not store precise movement trajectory history.
- Voice transcription content is only sent to Luma first-party backend services for product processing; it is not sent to third-party external services.

### 10.4 Observability
- Must log client-side and server-side search latency, summary latency, and feedback submit success rate.
- Must log key accessibility events (announcement trigger, abnormal focus landing).

## 11. External Dependencies and Constraints
- iOS system capabilities: VoiceOver, Speech, CoreLocation, BackgroundTasks.
- Data strategy: MVP uses backend APIs + PostgreSQL as source of truth, with iOS local cache/outbox for offline continuity.
- Permission strategy: Denial of any permission must not block the main search/details flow.

## 12. Risks and Mitigations
- Low data volume at cold start can reduce summary value.
  - Mitigation: Explicit low-confidence prompt + prominent latest update time.
- Speech recognition errors in noisy environments.
  - Mitigation: Pre-submit confirmation and editable content.
- Early-stage low review coverage may reduce summary representativeness.
  - Mitigation: low-confidence label, review-count display, and recency timestamp in all summaries.

## 13. Acceptance Criteria (Must Meet Before Release)
- VoiceOver-only can complete: search place, listen to summary, submit feedback, view nearby.
- Three local demo roles can switch, and permission isolation is enforced by role.
- Full flow does not rely on QR codes.
- Under permission denial, app does not crash and provides executable alternative paths.
- Cached data and queued feedback are recoverable across restarts.
- Place summary fields are always complete, with fallback text when data is missing.

## 14. Milestones and Deliverables
- Week 1: App shell, navigation, accessibility toolkit, local role switching, and home focus/announcement rules.
- Week 2: End-to-end integration of search and summary.
- Week 3: End-to-end integration of voice feedback submission and confirmation flow.
- Week 4: Nearby places and recent reviews completed.
- Week 5: Backend score-calculation stability, accessibility testing, and TestFlight release preparation.

Deliverables:
- Runnable iOS MVP package.
- Backend API contract, backend schema/migration scripts, and iOS cache/outbox schema scripts.
- Requirements acceptance checklist and test report.
