# Luma1

Luma1 is an accessibility app that helps visually impaired users navigate indoor spaces more independently using voice/text input, AI responses, maps, and community accessibility reviews.

## How to Run
- Open `Luma1.xcodeproj` in Xcode
- Run the app on an iPhone simulator or a physical iPhone

## Main Features
- Voice or text place search
- AI-powered personalized responses
- Map integration
- Accessibility review creation
- VoiceOver-focused accessibility improvements

## Judge Testing Notes
- Start from the home/sign-in flow
- Try voice or text input on the search page
- View the map updates
- Try creating and submitting a review
- VoiceOver can be enabled to test accessibility features

## Notes
- Built with Swift and SwiftUI
- Final version is frontend-focused
- Designed for visually impaired users, with community feedback features

## AI Usage
- We used the Qwen API to generate responses to user questions
- The app sends user input (voice or text) along with context (location, history, reviews)
- The AI returns a concise, personalized answer
- We did not train our own model; we used a pre-trained AI model via API

## Development Note
Earlier iterations included backend-based AI integration. The final version shifted more functionality to the frontend for improved speed and reliability.