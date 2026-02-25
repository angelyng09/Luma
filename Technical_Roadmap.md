**1. Goal Overview**
Focused on accessible information access for indoor spaces, community co-creation, and real-time feedback. The goal is to help visually impaired users quickly understand venue conditions both before traveling and after arrival, while providing continuous feedback to support venue improvements.

**2. Core User Scenarios & Flow**
2.1 Before Traveling (Voice Search → Evaluation → Decision)
- Voice input such as: “I want to go to XX hospital / mall / library.”
- Return a list of candidate locations (including distance, rating, accessibility highlights, and recent feedback).
- Enter location details to review accessibility dimension scores and comments, then decide whether to go.

2.2 After Arrival (QR Scan → Layered Information → Quick Orientation)
- Scan QR codes at entrances, floors, or zones to access accessibility information for that area.
- Information is displayed hierarchically: Floor → Area → Facility points (e.g., restrooms, elevators, service desks).
- Supports one-tap voice playback and quick summaries (e.g., “The accessible restroom on this floor is on the east side; the elevator is operating normally.”)

2.3 Real-Time Feedback (Voice Submission → Community Sync → Venue Improvement)
- Users submit real-time feedback via voice, such as “The elevator is broken” or “The accessible restroom is locked.”
- Feedback appears in the community feed with timestamps and location tags, alerting other users.
- Feedback is also synced to the venue’s account as a basis for improvements.

**3. Accessibility Dimension Design (Extensible)**
Recommended initial dimensions:
- Accessibility / Reachability: Whether entrances and pathways are accessible; presence of steps or ramps.
- Core Facilities: Availability of accessible restrooms, elevators, service desks, etc.
- Signage & Guidance: Clarity of signage; availability of audio guidance.
- Safety & Comfort: Floor obstacles, crowd density, noise, lighting (including peak-time congestion level).
- Information Timeliness: Time of the most recent feedback; frequency of recent issues.

Scoring recommendations:
- Each dimension scored from 0–5, with a weighted total score based on importance.
- Display both “last updated time” and “sample size” alongside scores to avoid misleading outdated data.
- Allow users to adjust dimension weights based on their needs (e.g., wheelchair users can prioritize elevators, accessible pathways, and automatic doors).

Future expandable dimensions:
- Indoor navigation system deployment (BLE / QR guidance coverage): navigation range, success rate, and positioning stability.
- Venue responsiveness: speed of issue resolution and quality of official responses.

**4. Technical Roadmap (Phased)**
Phase A: Voice Search & Accessibility Evaluation
- Speech recognition for location keywords (built-in + online ASR).
- Location search returns candidate lists, sortable by distance, rating, or accessibility level.
- Detail pages display accessibility dimension scores and reviews.

Phase B: Future Expansion (Indoor Guidance & Voice Prompts)
- BLE beacons combined with QR codes for positioning and guidance.
- Voice prompt nodes (e.g., “Turn left in 5 meters to reach the elevator”).
- Deployment of guidance systems included as part of accessibility dimension scoring.

Phase C: Real-Time Voice Feedback & Community Sync
- Speech-to-text with structured tags (elevator malfunction, restroom congestion, etc.).
- Feedback stored instantly and pushed to the community feed and venue accounts.

**5. MVP Scope (Competition Phase)**
- The MVP does not include indoor navigation, and focuses on:
- Voice-based location search
- Accessibility dimension ratings and reviews
- Voice feedback → community synchronization

**6. Client Implementation (SwiftUI)**
6.1 Main Modules
- Voice Input Module: speech recognition, candidate correction, secondary confirmation.
- Location Search & Detail Module: lists, ratings, reviews, dimension breakdowns.
- Voice Playback Module: TTS output for key results.
- Feedback Submission Module: voice transcription, tag selection, submission confirmation.

6.2 Key Experience Requirements
- VoiceOver support, adjustable font sizes, high-contrast mode.
- Minimal steps and avoidance of complex forms.
- Clear voice and haptic feedback for all actions.

**7. Data & Backend Design (Simplified)**
7.1 Core Data Models (Simplified Fields)
- Place: id, name, address, coordinates, type, aggregated ratings
- AccessibilityDimension: dimension name, score, description
- Review: user id, rating, dimension scores, comment, timestamp
- FacilityPoint: location, facility type, availability status
- RealtimeFeedback: voice transcript, tags, timestamp, area

**8. Content & Quality Assurance**
- Lightweight moderation: sensitive word and spam filtering.
- Credibility indicators: display “last feedback time + feedback frequency.”
- Allow venue accounts to respond and update status.

**9. Privacy & Security**
- Anonymous contributions by default; optional real-name support.
- Voice data used only for transcription and prompts, with no secondary use.
- Users can delete their own feedback records at any time.

**10. Suggested Milestones (Competition Timeline)**
Week 1: Requirements freeze + prototype + data structure confirmation
Week 2: Voice search + list/detail pages
Week 3: QR information display + voice playback
Week 4: Voice feedback + community feed + polishing

**11. Risks & Mitigation**
Cold-start data: Partner with venues to import baseline information.
Feedback credibility: Introduce time-weighting and multi-report consistency indicators.
Scenario complexity: Exclude indoor navigation in MVP to reduce technical risk.
