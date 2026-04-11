# Luma Backend (`/ai/ask`)

## 1. Setup

```bash
cd backend
npm install
cp .env.example .env
```

Set `QWEN_API_KEY` in `.env`.

Example:

```env
QWEN_API_KEY=YOUR_API_KEY_HERE
```

For most Qwen keys, use:

```env
QWEN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
```

## 2. Run

```bash
npm start
```

Backend runs on `http://localhost:8080` by default.

If `npm` is not on your shell path, run:

```bash
./backend/start-backend.sh
```

Verified URLs:

- Simulator: `http://127.0.0.1:8080/ai/ask`
- Physical iPhone on same Wi-Fi/LAN: use the LAN URL printed by backend startup logs,
  for example `http://192.168.3.22:8080/ai/ask`

## 3. Endpoint

`POST /ai/ask`

Request:

```json
{
  "question": "Is this place wheelchair accessible?",
  "context": {
    "lastVisitedPlaceName": "Sample Place A",
    "currentLocation": {
      "latitude": 31.2304,
      "longitude": 121.4737
    },
    "reviews": [
      {
        "placeName": "Sample Place A",
        "note": "Entrance has one step, staff helped with portable ramp.",
        "rating": 4
      }
    ]
  }
}
```

Response:

```json
{
  "answer": "Short concise answer..."
}
```

## 4. Notes

- Keep `QWEN_API_KEY` only on backend, never in the iOS app.
- Never commit `.env` files or paste real keys into code, logs, or docs.
- Response language is auto-selected by input language (`zh` if Chinese characters are detected, otherwise English).
- Output is constrained to concise key information.
- App-provided `context` is treated as trusted grounding data and prioritized in answer generation.
