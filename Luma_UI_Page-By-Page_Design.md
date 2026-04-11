# Luma UI Detailed Pagination Design (Text Version)

## 1. Document Information
- Document Name: Luma UI Detailed Pagination Design (Text Version)
- Applicable Version: Luma iOS MVP (local demo identities)
- Updated On: 2026-04-03
- Design Principles: VoiceOver-first, low interaction cost, shared data + offline fallback loop

## 2. Global Design Guidelines

### 2.1 Navigation and Information Architecture
- Navigation approach: `NavigationStack` single-stack navigation to avoid deep modal nesting.
- Main navigation entry points on Home: 3 primary buttons (`Search`, `Nearby`, `Replay Tutorial`) + a persistent bottom icon menu.
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

### 2.5 Accessibility Scoring Rules (MVP)
- Each place has an on-device score snapshot with:
  - `accessibility_score`
  - `review_count_30d`
  - `review_count_90d`
  - `review_count_total`
  - `dimension_uncertain_flags`
  - top positive points and top issues
  - update timestamps
- The app always shows score as a whole number from `0` to `100`.
- Scoring dimensions and suggested weights:
  - Entrance accessibility `15%`
  - Route clarity `15%`
  - Vertical mobility availability `12%`
  - Restroom accessibility `10%`
  - Obstacles and hazards `12%`
  - Staff assistance availability `10%`
  - Crowd and queue manageability `10%`
  - Environmental perceivability `8%`
  - Temporary disruption impact `8%`
- Scoring formula:
  - Each dimension is rated on `1-5`.
  - Since weights already sum to `100`, implementation can use either equivalent form:
  - `final_score = sum(dimension_rating_1_to_5 * weight_percent) / 5`
  - `final_score = weighted_average_rating * 20`
  - Scores are rounded to the nearest integer.
- Evidence behavior:
  - Newer evidence counts more than older evidence (time decay).
  - Use review signals and venue-status signals mapped to the nine dimensions.
  - If a dimension has no recent evidence, set that dimension rating to neutral `3` and mark it as `uncertain`.
  - Temporary disruption signals decay faster than permanent accessibility signals.
  - Suggested decay windows: permanent features `90` days, temporary disruptions `7-14` days.
- Safety cap rule:
  - Staff assistance cannot fully compensate for major structural barriers.
  - If Entrance accessibility rating is `<= 2`, cap overall score at `60`.
- Review eligibility:
  - Include only `active` and `confirmed` reviews.
  - Exclude `flagged`, `hidden`, and `removed` reviews.
- Refresh timing:
  - Recompute after a user confirms a review.
  - Recompute after venue status updates.
  - Run a lightweight consistency recompute when app returns to foreground.
- Low confidence rule:
  - Show `Low confidence` if `confirmed_reviews_last_90d < 3` OR `confirmed_reviews_total < 5`.
- If valid data is missing or very limited, show a neutral score with caution messaging.

## 3. Page List (by Priority)

### P0 Pagesin
1. Login and Role Page (Login + Role Switch)
2. First-Time Tutorial Page (Tutorial) (Make last; screen record using the app & add voiceover)
3. Home Page (Home)
4. Search Bar (Search) (Same page as Search Results Page)
5. Search Results Page (Search Results)
6. Place Detail Page (Place Detail)
7. Review Capture Page (Review Capture)
8. Review Confirm Page (Review Confirm)
9. Nearby Page (Nearby) (Integrate into search page) 

- App layout: persistent bottom icon menu (visible only after Login and Tutorial pages):
  - Left icon: `Settings`
  - Center icon: `Home`
  - Right icon: `Create Review`
  - `Create Review` prefills place as a suggestion only: recent searched place (within 24h) first, then recent visited/reviewed place; users can always edit manually.

### P1 Pages (admin/demo capabilities)
10. Settings Page (Check role, change username/password, delete account)
11. Venue Maintenance Page (Venue Maintenance) 
12. Community Moderation Page (Community Moderation)
13. Local Data Tools Page (Local Data Tools)

## 4. Detailed Pagination Design

## 4.1 Login and Role Page (Login + Role Switch)
- Choose roles after signing up/automatically select role after logging in
- 1 role per user 
- Option to add profile picture 

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
- Only for new users
- Mainly audio with visual tutorial
  - Users will typically be assisted 

**Page Goal**
- Help new users quickly understand core operations.
- Bottom icon menu is hidden on this page.

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
- This is the first page where the persistent bottom icon menu appears.

**Entry Conditions**
- First-time user path: Login and Role -> Tutorial -> Home.
- Returning user with completed tutorial: Login/role restore -> Home.
- Bottom icon menu is hidden on Login and Tutorial pages, and shown from Home onward.

**Layout Structure**
1. Title: `Luma Home`
2. Current role tag (read-only): `Current role: xxx`
3. Three main buttons (vertical):
   - Search Places
   - Nearby Places
   - Replay Tutorial
4. Secondary entries: `Switch Role`, `Local Data Tools` (visibility controlled by role)
5. Bottom menu bar (persistent, icon-based):
   - Left icon: `Settings`
   - Center icon: `Home` (active on Home page)
   - Right icon: `Create Review`

**Key Interactions**
- Tap a main button to enter the corresponding flow.
- Tap `Create Review` from the bottom bar to jump to Review Capture:
  - First-time/no-history users start with empty place input.
  - If recent search result exists within 24h, prefill that place as suggestion.
  - Otherwise fallback to recent visited/reviewed place as suggestion.
  - Place remains fully editable.
- Tap `Settings` to open user/settings page.
- Tap `Home` icon to return to the Home page root.

**State Design**
- Startup check in progress: Main buttons disabled.
- Check failed: Show Retry button.

**VoiceOver Design**
- First focus: `Luma Home`.
- Entry announcement: `Home. Please choose Search or Nearby.`
- Bottom menu icons announce labels in order: `Settings`, `Home`, `Create Review`.

---

## 4.4 Search Bar
- Voice/text input
- Users can include needs that the AI will use as filters for displaying locations in the Search Results Page 


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
- Show highest rated locations first
- 5 locations per page
- Also factor in distance of the location from the user
- Press to have voiceover present info for each location
  - Simple voiceover: name, overall rating, location
  - Detailed voiceover: ratings for each factor in conversational tone (eg: pros/cons), voice input to ask a question & get AI voiceover answer based on location info + reviews
    - Ratings for each factor can be read depending on the user's desired factors -> users directly ask through voice input 
    - AI response based on reviews needs to determine which reviews to use (eg: don't use reviews older than 1 year)
    - AI response can be based on maintenance users' instructions too if there are any 
    - Reorder locations based on user questions/needs
    - Allow follow-up questions through button/touch gesture 
  - Save user details/needs based on previous questions & mention them in detailed voiceover if possible 

- Click on individual location to jump to Place Detail Page

- AI model: doubao(?)

**Page Goal**
- Let users quickly compare candidate places and enter details.

**Layout Structure**
1. Title: `Search Results`
2. Results list (card rows):
   - Place name
   - Distance & location
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
4. Info area: `Latest update time`, `Review count in last 30 days`, `Confirmed reviews in last 90 days`, `Confirmed reviews total`
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
  - `review_count_90d`
  - `review_count_total`
  - `top_positive_json` (Top 2)
  - `top_negative_json` (Top 2)
  - `last_review_at`
- Internal rule reference (not required to expose in UI):
  - Score is derived from nine weighted dimensions, each rated `1-5`.
  - Use `sum(dimension_rating_1_to_5 * weight_percent) / 5` (equivalent to `weighted_average_rating * 20`).
  - If any dimension has no recent evidence, that dimension defaults to neutral `3` and is marked `uncertain`.
  - If Entrance accessibility rating is `<= 2`, cap overall score at `60`.
- Confidence display rule:
  - If `confirmed_reviews_last_90d < 3` OR `confirmed_reviews_total < 5`, append `Low confidence` and keep caution copy visible.
- Do not show separate scores by role; all roles read the same place-level score output.

**State Design**
- Loading: `Loading place summary`.
- Missing data: Show fallback text `Current data is limited. Please reference with caution`.
- Low confidence: Show score with inline note `Low confidence: based on limited confirmed evidence`.
- Score refresh pending (after submit): keep last snapshot visible and show `Updating latest community signal`.

**VoiceOver Design**
- First focus: Place title.
- Entry announcement: `Accessibility score X out of 100. Swipe right for details.`
- If low confidence: append `Low confidence due to limited confirmed evidence.`

---

## 4.7 Review Capture Page (Review Capture)
**Page Goal**
- Let users save a structured accessibility review with minimal effort while keeping place selection flexible.

**Layout Structure**
1. Title: `Create Review`
2. Place suggestion area:
   - If recent search result is fresh (<= 24h): show it as suggested prefill.
   - Else if recent visited/reviewed place exists: show it as fallback suggestion.
   - Else: show no-suggestion helper text for first-time users.
3. Place text input (editable, required)
4. Secondary place actions:
   - `Search and Select Place` (navigates to Search page)
   - `Use Recent Search: {place}` (visible when recent search exists)
5. Rating input (`1-5`)
6. Accessibility notes input (required)
7. Primary action: `Next: Confirm`
8. Recent in-app reviews list (latest first)

**Key Interactions**
- Users can always type a different place than the suggested one before saving.
- Tapping `Search and Select Place` opens Search flow; after returning, latest search can be applied as place suggestion.
- Tapping `Next: Confirm` opens Review Confirm page for final save.

**State Design**
- No suggestion state: place field stays empty with helper copy.
- `Next: Confirm` enabled only when place and notes are both non-empty.
- After confirm-save success, show inline success message on capture page and refresh recent review list.

**VoiceOver Design**
- First focus: page title `Create Review`.
- Suggested-place copy explicitly states that place is editable.
- Save success announcement: `Review saved and available for AI context.`

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
- Tap "Confirm Save" to persist review to local store and return to Place Detail.
- If local write fails, preserve draft and allow immediate retry.
- On successful save, trigger local score/summary recompute for that place.

**State Design**
- Save success: Toast + voice announcement.
- Save failed: Error prompt + retry.
- Save success but summary recompute pending: return to Place Detail with previous snapshot and loading hint for refreshed score.

**VoiceOver Design**
- Success announcement: `Review submitted`.
- Save-failed announcement: `Review save failed. Draft kept locally. Please try again.`

---

## 4.9 Nearby Page (Nearby)
- Integrate into search page: user can ask for nearby locations 

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

## 4.10 Settings Page (Settings)
**Page Goal**
- Provide a simple account management page for current MVP scope.
- Let users check current role, change username/password, and delete account.

**Entry Conditions**
- Entered from the bottom menu `Settings` icon.
- Bottom menu is visible only after Login and Tutorial are completed.
- Available to all roles.

**Layout Structure**
1. Title: `Settings`
2. Account summary area:
   - Current role (read-only)
   - Current username
3. Account actions:
   - `Change Username`
   - `Change Password`
   - `Delete Account` (destructive)
4. Confirmation area:
   - Delete confirmation prompt before final delete action.

**Key Interactions**
- Tap `Change Username` to edit and save a new username.
- Tap `Change Password` to edit and save a new password.
- Tap `Delete Account` to open a confirmation step, then permanently delete local account data.

**State Design**
- Saving state: disable repeat submit and show loading feedback.
- Save success: show inline success message and voice announcement.
- Save failed: show inline error and keep user input for retry.
- Delete success: clear account/session-related local data and return to Login and Role page.

**VoiceOver Design**
- First focus: `Settings` title.
- Save success announcement: `Settings updated`.
- Delete confirmation announcement: `Delete account confirmation`.
- Delete success announcement: `Account deleted. Returned to login.`

---

## 4.11 Venue Maintenance Page (Venue Maintenance, maintenance role)
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

## 4.12 Community Moderation Page (Community Moderation, management role)
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

## 4.13 Local Data Tools Page (Local Data Tools)
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
- First open or invalid local role -> Login and Role Page -> Tutorial Page -> Home Page
- Existing user reopen with valid local role -> Home Page (direct)
- Home Page -> Search Page -> Search Results Page -> Place Detail Page
- Home Page -> Nearby Page -> Place Detail Page
- Home Page/Place Detail Page -> Review Capture Page -> Review Confirm Page -> Place Detail Page
- Home Page -> Settings Page
- Home Page (role-based) -> Venue Maintenance Page / Community Moderation Page / Local Data Tools Page
- Bottom icon menu visibility: hidden on Login/Tutorial, visible from Home onward.

## 6. Page-Level Acceptance Checklist
- First focus on every page is the title.
- Each page has at least one primary action reachable within 3 swipes.
- Key states (loading, success, failure, no permission) all include voice announcements.
- After role switch, restricted entry points are hidden immediately or set to read-only on the current page.
