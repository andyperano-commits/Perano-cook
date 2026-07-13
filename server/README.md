# Perano Cook AI backend

Small Express server that proxies Claude API calls for the app's AI features
(chat assistant, recipe link import, AI meal planning, smart grocery merge).
It holds the Anthropic API key server-side so it's never exposed in the
browser.

## Setup

```sh
cd server
npm install
cp .env.example .env   # then fill in ANTHROPIC_API_KEY
npm start
```

This serves both the API (`/api/*`) and the Perano Cook app itself at
`http://localhost:8787` — open that URL and everything works with no further
configuration.

## Deploying the frontend separately

If you host the static app elsewhere (e.g. GitHub Pages) instead of using
this server's built-in static hosting, open the app's **Settings → AI
Assistant** tab and set **Backend URL** to wherever this server is deployed
(e.g. `https://your-backend.example.com`). Set `CORS_ORIGIN` in `.env` to
that frontend's origin.

## Environment variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | yes | — | From the Anthropic Console |
| `ANTHROPIC_MODEL` | no | `claude-opus-4-8` | Swap for a cheaper/faster model if you like |
| `PORT` | no | `8787` | |
| `CORS_ORIGIN` | no | `*` | Set to your frontend's origin in production |
