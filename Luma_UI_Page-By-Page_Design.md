# Luma UI Detailed Pagination Design (Text Version)

## 1. Document Information
- Document Name: Luma UI Detailed Pagination Design (Text Version)
- Applicable Version: Luma iOS MVP (local demo identities)
- Updated On: 2026-03-09
- Design Principles: VoiceOver-first, low interaction cost, shared data + offline fallback loop

## 2. Global Design Guidelines

### 2.1 Navigation and Information Architecture
- Navigation approach: `NavigationStack` single-stack navigation to avoid deep modal nesting.
- Main navigation entry points: 4 main buttons on Home (Search, Nearby, Feedback, Replay Tutorial).
- Role-related entry points: Unified access through the "Role Switch" page, avoiding frequent interruptions in normal flows.

### 2.2 Global Page Skeleton
Each page follows the same structure:
1. Top: Page title + Back/Close.
2. Main content area: Ordered top-to-bottom by task flow.
3. Bottom fixed action area: Primary button (Confirm/Submit/Save).

### 2.3 Global VoiceOver Guidelines
- First focus is fixed on the page title.
- Every tappable element provides `accessibilityLabel` and `accessibilityHint`.
- Important state changes must include voice announcements (loading, success, failure, insufficient permissions).
- Focus order must strictly follow visual order: top-to-bottom, left-to-right.

### 2.4 Visual and Readability Guidelines
- Recommended primary button height: >= 52pt.
- Recommended list row height: >= 56pt.
- Title/body contrast must meet WCAG AA.
- Support Dynamic Type up to Accessibility Large.

### 2.5 Global Scoring Rule Binding (MVP)
- Each place has a backend summary with:
  - `accessibility_score`
  - `review_count_30d`
  - top positive points and top issues
  - update timestamps
- The app always shows score as a whole number from `0` to `100`.
- Scoring behavior:
  - Newer reviews count more than older reviews.
  - Review ratings are combined into one average, then converted to `0-100`.
  - If active reviews in the last 30 days are fewer than `3`, cap score at `65` and show `Low confidence`.
- Review eligibility:
  - Include only `active` reviews.
  - Exclude `flagged` and `removed` reviews.
- Refresh timing:
  - Recompute after a user confirms a review.
  - Also recompute every 15 minutes as fallback.
- If valid data is missing or very limited, show a neutral score with caution messaging.

## 3. Page List (by Priority)

### P0 Pages
1. Login and Role Page (Login + Role Switch)
2. First-Time Tutorial Page (Tutorial)
3. Home Page (Home)
4. Search Page (Search)
5. Search Results Page (Search Results)
6. Place Detail Page (Place Detail)
7. Review Capture Page (Review Capture)
8. Review Confirm Page (Review Confirm)
9. Nearby Page (Nearby)

### P1 Pages (admin/demo capabilities)
10. Venue Maintenance Page (Venue Maintenance)
11. Community Moderation Page (Community Moderation)
12. Local Data Tools Page (Local Data Tools)

## 4. Detailed Pagination Design

## 4.1 Login and Role Page (Login + Role Switch)
**Page Goal**
- Let users enter the app by selecting a local demo identity.
- Support fast role switching without real authentication.

**Entry Conditions**
- First open (no local role saved): this page is mandatory.
- Existing user app reopen (valid local role saved): skip this page and enter Home directly.
- Existing user app reopen (missing/invalid local role): force this page in mandatory mode.
- Role switch from Home: this page opens with current role preselected.

**Layout Structure**
1. Top area
   - Title: `Login and Select Role`
   - Subtitle: `This MVP uses local demo identities. No password required.`
2. Identity card list (single-select, 3 cards):
   - Visually Impaired / Low Vision User
   - Venue Maintenance
   - Community Management
   - Each card includes:
     - Role name
     - One-line capability summary
     - Selection state (`Selected` / `Not selected`)
3. Bottom fixed action area:
   - Primary button: `Continue`
   - Secondary text action: `Cancel` (only visible when entered from Home role switch)

**Copy Rules**
- If no role selected: primary button label remains `Continue` but disabled.
- If role selected: helper text shows `You are continuing as {role name}`.

**Key Interactions**
- Tap a role card to select it (single-select behavior; selecting a new card deselects the previous one).
- Double-tap selected card again keeps current selection (no toggle-to-empty state).
- Tap `Continue` to persist role locally and navigate:
  - First open: go to Home.
  - From Home role switch: return to Home and refresh role-based entry points immediately.
- Tap `Cancel` (if present) to return to Home without changing role.

**Data and Rule Binding**
- Local persistence keys:
  - `current_role`
  - `last_role_switch_at`
- No network request, no password validation, no token/session creation.
- If persisted role is invalid/corrupted, clear role and force this page in mandatory mode.

**State Design**
- Initial mandatory mode (no saved role):
  - No selection by default.
  - `Continue` disabled.
- Auto-entry mode (existing user with valid saved role):
  - System reads `current_role` and navigates directly to Home.
  - Login and Role Page is not shown.
- Switch mode (entered from Home):
  - Current role preselected.
  - `Continue` enabled.
- Saving:
  - `Continue` shows loading style and is temporarily disabled to prevent double-submit.
- Save success:
  - Navigate and announce switched role.
- Save failure (local write error):
  - Inline error: `Unable to save role locally. Please try again.`
  - Keep selection and re-enable `Continue`.

**Permission Visibility Hint**
- Show one-line note under each role card:
  - User role: `Search, Nearby, Submit feedback`
  - Venue role: `Edit venue status fields`
  - Community role: `Moderate community feedback`

**VoiceOver Design**
- First focus: Page title.
- Focus order: Title -> Subtitle -> Role cards (top to bottom) -> `Continue` -> `Cancel`.
- Card readout format: `{Role name}, role card, {selected/not selected}, double-tap to select`.
- Selection change announcement: `{Role name} selected`.
- Disabled button hint: `Select a role to continue`.
- Success announcement on entry: `Switched to {role name}`.
- Failure announcement: `Role switch failed. Try again.`

**Acceptance Checks**
- Users can complete role selection and enter Home in <= 2 interactions after selection.
- Role change takes effect immediately on Home (visible entry points and executable actions update).
- No real login/authentication screens or auth API calls are triggered.
- VoiceOver can complete the full flow without requiring custom gestures.

---

## 4.2 First-Time Tutorial Page (Tutorial)
**Page Goal**
- Help new users quickly understand core operations.

**Layout Structure**
1. Title: `Luma Audio Tutorial`
2. Tutorial content area: Current chapter title + brief description
3. Control button row: `Play/Pause`, `Repeat`, `Skip`, `Complete`

**Key Interactions**
- Tap "Complete" to write `tutorial_completed=true` and return to Home.

**State Design**
- Audio loading: show `Loading tutorial`.
- Audio failed: show readable text tutorial and allow continuation.

**VoiceOver Design**
- Entry announcement: `Welcome to the Luma tutorial. You can play, repeat, skip, or complete.`
- Completion announcement: `Tutorial completed. Returned to Home.`

---

## 4.3 Home Page (Home)
**Page Goal**
- Serve as the distribution hub for all core tasks.

**Layout Structure**
1. Title: `Luma Home`
2. Current role tag (read-only): `Current role: xxx`
3. Four main buttons (vertical):
   - Search Places
   - Nearby Places
   - Review Current Place
   - Replay Tutorial
4. Secondary entries: `Switch Role`, `Local Data Tools` (visibility controlled by role)

**Key Interactions**
- Tap a main button to enter the corresponding flow.

**State Design**
- Startup check in progress: Main buttons disabled.
- Check failed: Show Retry button.

**VoiceOver Design**
- First focus: `Luma Home`.
- Entry announcement: `Home. Please choose Search, Nearby, or Review Current Place.`

---

## 4.4 Search Page (Search)
**Page Goal**
- Support both text and voice input for place keywords.

**Layout Structure**
1. Title: `Search Places`
2. Search input field
3. Microphone button (voice input)
4. Search button
5. Recent searches (up to 5)

**Key Interactions**
- Trigger backend search request after entering keywords (fall back to local cache when needed).
- Tap a recent search to reuse keywords in one step.

**State Design**
- Searching: Show loading state.
- No results: Show `No matching places found`.
- Error: Show `Search failed. Please try again`.

**VoiceOver Design**
- First focus: Search input field.
- Searching announcement: `Searching`.
- Completion announcement: `Found X places`.

---

## 4.5 Search Results Page (Search Results)
**Page Goal**
- Let users quickly compare candidate places and enter details.

**Layout Structure**
1. Title: `Search Results`
2. Results list (card rows):
   - Place name
   - Distance
   - Accessibility score
   - Optional confidence tag (`Low confidence` when evidence is limited)
   - Latest update time
3. Sorting control: `Distance First` / `Score First`

**Key Interactions**
- Tap a result row to open Place Detail.
- Adjust sorting to refresh list order instantly.

**VoiceOver Design**
- Row readout template: `{place name}, distance {x} meters, score {y}, {confidence state if any}, double-tap for details.`

---

## 4.6 Place Detail Page (Place Detail)
**Page Goal**
- Provide core decision information for "whether to go".

**Layout Structure**
1. Title: Place name
2. Score area: `Accessibility confidence score X/100`
3. Two-column highlights area:
   - Doing Well (Top 2)
   - Common Issues (Top 2)
4. Info area: `Latest update time`, `Review count in last 30 days`
5. Action area:
   - Review Current Place
   - View Recent Reviews

**Key Interactions**
- Tap "Review Current Place" to enter Review Capture.
- Tap "View Recent Reviews" to enter the review list.

**Data and Rule Binding**
- Read summary from snapshot fields:
  - `accessibility_score` (0-100)
  - `review_count_30d`
  - `top_positive_json` (Top 2)
  - `top_negative_json` (Top 2)
  - `last_review_at`
- Confidence display rule:
  - If `review_count_30d < 3`, append `Low confidence` and keep caution copy visible.
- Do not show separate scores by role; all roles read the same place-level score output.

**State Design**
- Loading: `Loading place summary`.
- Missing data: Show fallback text `Current data is limited. Please reference with caution`.
- Low confidence: Show score with inline note `Low confidence: based on limited recent reviews`.
- Score refresh pending (after submit): keep last snapshot visible and show `Updating latest community signal`.

**VoiceOver Design**
- First focus: Place title.
- Entry announcement: `Accessibility score X out of 100. Swipe right for details.`
- If low confidence: append `Low confidence due to limited recent reviews.`

---

## 4.7 Review Capture Page (Review Capture)
**Page Goal**
- Complete voice feedback capture with low effort.

**Layout Structure**
1. Title: `Voice Feedback`
2. Recording controls: `Start Recording` / `Stop Recording`
3. Transcript preview (editable)
4. Secondary actions: `Re-record`, `Clear Text`
5. Bottom primary button: `Next: Confirm`

**Key Interactions**
- After recording, run transcription and fill text box.

**State Design**
- Recording: Show real-time status and duration.
- Transcribing: Show `Transcribing`.
- Permission denied: Show "Go to Settings" + text input fallback.

**VoiceOver Design**
- First focus: `Start Voice Feedback` button.
- Transcription completion announcement: `Transcript ready. Confirm or edit.`

---

## 4.8 Review Confirm Page (Review Confirm)
**Page Goal**
- Confirm structured output matches original text before saving.

**Layout Structure**
1. Title: `Confirm Review`
2. Original text area
3. Auto-parsing result area:
   - Signal type
   - Suggested score
4. Button group: `Confirm Save`, `Back to Edit`, `Cancel`

**Key Interactions**
- Tap "Confirm Save" to submit review to backend and return to Place Detail.
- If offline or request fails, queue review locally and retry in background.
- On successful submit, trigger score/summary recompute for that place.

**State Design**
- Save success: Toast + voice announcement.
- Save failed: Error prompt + retry.
- Save success but summary recompute pending: return to Place Detail with previous snapshot and loading hint for refreshed score.

**VoiceOver Design**
- Success announcement: `Review submitted`.
- Offline queued announcement: `Review queued. It will send when connection is available.`

---

## 4.9 Nearby Page (Nearby)
**Page Goal**
- Quickly view nearby reference places after arrival.

**Layout Structure**
1. Title: `Nearby Places`
2. Status bar: Location permission and current position status
3. Nearby list (500m): Place name, distance, score, optional `Low confidence` tag
4. Permission-denied fallback area: Manual search entry

**Key Interactions**
- Tap a place to enter Place Detail.

**State Design**
- Loading: `Finding nearby places`.
- Location denied: Show `Location access is off. Use search instead.`

**VoiceOver Design**
- First focus: Title.
- Update announcement: `X nearby places within 500 meters.`

---

## 4.10 Venue Maintenance Page (Venue Maintenance, maintenance role)
**Page Goal**
- Demonstrate venue maintenance role capability to update venue status.

**Layout Structure**
1. Title: `Venue Maintenance`
2. Venue selector
3. Status edit form:
   - Elevator status (Available/Unavailable)
   - Restroom accessibility (Normal/Limited)
   - Temporary issue flag (On/Off)
4. Bottom button: `Save Changes`

**Permission Rules**
- Only "Venue Maintenance Account" can edit and save.
- Community management is read-only; regular users cannot see this page.

**VoiceOver Design**
- Save success announcement: `Venue status updated`.
- No-permission announcement: `Current role has no operation permission`.

---

## 4.11 Community Moderation Page (Community Moderation, management role)
**Page Goal**
- Demonstrate community management role capability to moderate feedback content.

**Layout Structure**
1. Title: `Community Moderation`
2. Feedback list (with status tags)
3. Per-row management buttons: `Flag`, `Hide`, `Restore`
4. Operation record area: Timestamp of recent moderation actions

**Permission Rules**
- Only "Community Management Account" can execute moderation actions.
- Venue maintenance account is read-only; regular users cannot see this page.

**VoiceOver Design**
- Action completion announcement: `Feedback flagged/hidden/restored`.

---

## 4.12 Local Data Tools Page (Local Data Tools)
**Page Goal**
- Support quick cache/outbox diagnostics and recovery during review and integration testing.

**Layout Structure**
1. Title: `Local Data Tools`
2. Action buttons:
   - Refresh from server
   - Clear local cache
   - Retry queued submissions
   - View sync status

**Permission Rules**
- Venue maintenance and community management can execute.
- Visually impaired/low-vision user is read-only and cannot execute destructive actions.

**VoiceOver Design**
- Operation success announcement: `Local data updated`.

## 5. Page Flow Relationships (Text Version)
- First open or invalid local role -> Login and Role Page -> Home Page
- Existing user reopen with valid local role -> Home Page (direct)
- Home Page -> Search Page -> Search Results Page -> Place Detail Page
- Home Page -> Nearby Page -> Place Detail Page
- Home Page/Place Detail Page -> Review Capture Page -> Review Confirm Page -> Place Detail Page
- Home Page (role-based) -> Venue Maintenance Page / Community Moderation Page / Local Data Tools Page

## 6. Page-Level Acceptance Checklist
- First focus on every page is the title.
- Each page has at least one primary action reachable within 3 swipes.
- Key states (loading, success, failure, no permission) all include voice announcements.
- After role switch, restricted entry points are hidden immediately or set to read-only on the current page.
