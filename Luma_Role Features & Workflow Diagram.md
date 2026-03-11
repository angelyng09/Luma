# Luma Role Features and Flowcharts

## 1. Document Information
- Document Name: Luma Role Features and Flowcharts
- Applicable Version: Luma iOS MVP (account-and-password authentication mode)
- Updated On: 2026-03-10

## 2. Role Definitions
- Visually Impaired/Low-Vision User Account: Core MVP user role, responsible for search, viewing, and feedback.
- Venue Maintenance Account: Authenticated operational role, responsible for maintaining venue status fields.
- Community Management Account: Authenticated moderation role, responsible for managing the status of community feedback content.

## 3. Role Feature List

| Feature Module | Visually Impaired/Low-Vision User Account | Venue Maintenance Account | Community Management Account |
|---|---|---|---|
| Account Login (email/username + password) | Supported | Supported | Supported |
| First-Time Tutorial Playback | Supported | Supported | Supported |
| Place Search (Text/Voice) | Supported | Supported | Supported |
| View Place Summary | Supported | Supported | Supported |
| View Recent Reviews | Supported | Supported | Supported |
| Submit Voice Feedback | Supported | Supported | Not Supported |
| View Nearby Places | Supported | Supported | Supported |
| Maintain Venue Status (facility availability, temporary issues) | Not Supported | Supported | Read-only |
| Community Feedback Management (flag/hide/restore) | Not Supported | Read-only | Supported |
| Local Data Management (refresh sync/clear cache/retry outbox) | Read-only | Supported | Supported |

## 4. Global Flowchart (Account-and-Password Authentication + Permission Routing)

```mermaid
flowchart TD
    A[Launch App] --> B[Enter Login Screen]
    B --> C[Submit Account and Password]
    C --> D{Authentication Successful?}
    D -- No --> E[Show Error and Stay on Login]
    D -- Yes --> F[Load Logged-In Account Role]

    F --> G{Current Role}
    G -- Visually Impaired/Low-Vision User --> U1[Show User Main Entry]
    G -- Venue Maintenance --> M1[Show Maintenance Main Entry]
    G -- Community Management --> G1[Show Management Main Entry]

    U1 --> H[Run Search/Nearby/Feedback Flows]
    M1 --> I[Run Venue Status Maintenance Flow]
    G1 --> J[Run Community Content Management Flow]

    H --> K[Submit or Sync via Backend API]
    I --> K
    J --> K
    K --> L{Network Available?}
    L -- Yes --> M[Refresh Summaries and Lists from Backend Snapshot]
    L -- No --> N[Queue Changes Locally and Retry in Background]
    N --> M
```

## 5. Visually Impaired/Low-Vision User Flowchart

```mermaid
flowchart TD
    A[Log In as Visually Impaired/Low-Vision User Account] --> B[Home]
    B --> C{Select Entry}
    C -- Search Place --> D[Enter Keywords by Text/Voice]
    C -- Nearby Places --> E[Request Location and Show Nearby List]
    C -- Review Current Place --> F[Start Voice Feedback]

    D --> G[View Candidate Results]
    G --> H[Enter Place Detail]
    E --> H
    H --> I[Read Summary: Score/Strengths/Issues/Updated Time]

    F --> J[Voice Transcription]
    J --> K[Rule Parsing: Signal Type/Suggested Score]
    K --> L[User Confirms or Edits]
    L --> M[Submit Feedback API]
    M --> N{Submit Success?}
    N -- Yes --> O[Refresh Place Summary Snapshot]
    N -- No --> P[Queue in Local Outbox]
    P --> O
```

## 6. Venue Maintenance Account Flowchart

```mermaid
flowchart TD
    A[Log In as Venue Maintenance Account] --> B[Enter Venue Maintenance Entry]
    B --> C[Select Target Venue]
    C --> D[Edit Status Fields]
    D --> E[Update Facility Availability]
    D --> F[Update Temporary Issue Flags]
    E --> G[Submit Venue Status Update API]
    F --> G
    G --> H[Backend Recomputes Summary Snapshot]
    H --> I[Frontend Detail Page Shows Latest Status]
```

## 7. Community Management Account Flowchart

```mermaid
flowchart TD
    A[Log In as Community Management Account] --> B[Enter Community Management Entry]
    B --> C[View Feedback List]
    C --> D{Choose Management Action}
    D -- Flag --> E[Set flagged]
    D -- Hide --> F[Set hidden]
    D -- Restore --> G[Restore active]
    E --> H[Submit Moderation API]
    F --> H
    G --> H
    H --> I[Refresh Community List and Place Summary]
```

## 8. Key Interaction and Permission Rules
- Permissions are granted only after successful account-and-password authentication and are determined by the logged-in account role (not by preset demo accounts).
- Visible page does not mean executable actions: roles without permission are read-only and cannot submit changes.
- All key state transitions (save success, insufficient permissions, operation failure) require voice announcements.
- All role flows use backend APIs as source of truth, with local cache/outbox fallback when offline.

## 9. Review and Acceptance Recommendations
- Verify login and permission routing by signing in with three different account credentials (page entries, button executability changes).
- Verify that "read-only roles" cannot perform restricted actions.
- Verify that backend state, cached state, and UI state remain consistent after actions by all three roles.
- Verify under VoiceOver that the login entry and key buttons are fully operable.
