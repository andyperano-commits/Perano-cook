# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state

The app's source (`index.html`, `app.js`, `styles.css`, `sw.js`,
`manifest.webmanifest`, `icons/`) is tracked directly at the repo root — edit
these files in place. (Earlier revisions of this repo shipped the source as a
zip archive instead; that archive has since been extracted and removed in
favor of tracking the real files.)

## What this is

Perano Cook is a private, offline-first recipe-book Progressive Web App:
recipes, a weekly meal planner, and a grocery list, all stored client-side.
There is no backend, no network calls, no accounts, and no build tooling —
it's plain HTML/CSS/JS served as static files. There is no `package.json`,
no bundler, no linter, and no test suite.

## Running it

Because the app registers a service worker (`sw.js`), it must be served over
`http://` (not opened via `file://`) or the service worker registration will
silently fail. From the extracted directory:

```bash
python3 -m http.server 8080   # or: npx serve .
```

Then open `http://localhost:8080/`. There are no build, lint, or test
commands — verify changes by loading the page in a browser and exercising
the tab you changed.

## Architecture

**`index.html`** — a single page containing five `<section id="tab-*">`
blocks (Recipes, Add, Planner, Groceries, Settings). There is no router;
`app.js` toggles visibility with a `.hidden` class based on which `nav.tabs`
button was clicked, and calls the matching `render*()` function to refresh
that tab's data from IndexedDB.

**`app.js`** — the entire application logic in one file, organized into
`// ---------- Section ----------` comment blocks (DB init → tab
switching → Recipes → recipe modal → voice notes → Planner → Groceries →
Backup/Restore → Init). Keep new code in this same flat, section-comment
style rather than introducing modules/bundling unless asked.

**Data layer**: IndexedDB (`perano-cook-db`, version 1) via the `tx(store,
mode)` helper, with four object stores created in `openDB()`'s
`onupgradeneeded`:
- `recipes` — autoIncrement `id`; fields include `title`, `link`,
  `ingredients` (array), `method`, `tags` (array), `photo` (a `File`/`Blob`
  stored directly, rendered later via `blobToDataURL`).
- `planner` — a single row keyed `'week'` holding a 7-element array (Mon–Sun)
  of arrays of recipe ids.
- `groceries` — a single row keyed `'list'` holding `{name, done}` items.
- `voices` — keyed by `recipeId`, holds `{id, notes: [Blob, ...]}` audio
  clips recorded via `MediaRecorder` (`voiceNoteForRecipe`). Note the
  recording UI uses a blocking `confirm()` as a stop button, and voice notes
  are excluded from JSON backups (called out explicitly in the Settings tab
  copy and in the backup code).

Since `planner` and `groceries` hold one global row each rather than a
collection, they're addressed by a fixed string key, unlike `recipes` which
uses numeric autoIncrement ids — don't conflate the two id schemes when
adding stores.

**Grocery generation** (`btn-generate-groceries`): collects every recipe id
referenced anywhere in the current week's planner, flattens their
`ingredients` arrays, and de-dupes naively by lowercased/trimmed string —
it does not parse quantities or units.

**Backup/Restore**: exports `recipes` (minus `photo`), `planner`, and
`groceries` as a downloaded JSON file; restore clears and repopulates those
three stores from an uploaded JSON file. Photos and voice notes are
intentionally not included.

**Service worker (`sw.js`)**: cache-first — `fetch` handler serves from
cache and falls back to network, with no runtime re-caching. `ASSETS` is
precached under `CACHE_NAME = 'perano-cook-v1'` on `install`; `activate`
deletes any cache whose name doesn't match `CACHE_NAME`. **Bump
`CACHE_NAME` whenever `ASSETS` or any cached file changes** — otherwise
users keep getting served stale cached files indefinitely.

**`manifest.webmanifest`**: PWA installability metadata (standalone
display, theme color, icons at `icons/icon-192.png` / `icons/icon-512.png`).

## Conventions worth knowing

- DOM is built imperatively (`createElement`/`textContent`) almost
  everywhere to avoid injecting untrusted strings as HTML — **except**
  `openRecipeModal`, which interpolates `r.title`, `r.link`, `r.ingredients`,
  and `r.method` into `innerHTML` unescaped. Since all data is local to the
  device (no shared/synced data), this isn't currently a cross-user XSS risk,
  but keep it in mind if this app ever gains any shared/imported data path.
- User feedback and simple input flows use native `alert()`/`confirm()`/
  `prompt()` rather than custom UI (e.g. `addToPlannerPrompt` asks for a day
  name via `prompt()`). Follow this lightweight pattern for similar
  interactions instead of adding custom modal components.
