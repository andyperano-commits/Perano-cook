require('dotenv').config();

const path = require('path');
const express = require('express');
const cors = require('cors');
const Anthropic = require('@anthropic-ai/sdk');

const PORT = process.env.PORT || 8787;
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-opus-4-8';

const client = new Anthropic(); // reads ANTHROPIC_API_KEY from env

const app = express();
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '2mb' }));

// Serve the PWA itself so `npm start` in server/ gives you the whole app on
// one origin (same-origin API calls, no backend URL to configure). Deploying
// the frontend separately (e.g. static hosting) still works — just point the
// app's Settings > AI Assistant > Backend URL at wherever this server runs.
app.use(express.static(path.join(__dirname, '..')));

function firstJsonTextBlock(content) {
  const textBlocks = content.filter((b) => b.type === 'text');
  for (let i = textBlocks.length - 1; i >= 0; i--) {
    try {
      return JSON.parse(textBlocks[i].text);
    } catch {
      // try the next candidate (e.g. commentary text before the final JSON block)
    }
  }
  throw new Error('Model did not return parseable JSON.');
}

// ---------- Cooking chat assistant ----------
app.post('/api/chat', async (req, res) => {
  try {
    const { messages, recipeContext } = req.body || {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'messages array is required' });
    }

    let system =
      'You are the in-app cooking assistant for Perano Cook, a private offline recipe book. ' +
      "Help with substitutions, technique questions, quick recipe ideas, and adapting the user's own recipes. " +
      'Keep answers short and practical unless asked for detail.';
    if (Array.isArray(recipeContext) && recipeContext.length > 0) {
      system += `\n\nThe user's saved recipes (title — tags): ${recipeContext
        .slice(0, 100)
        .map((r) => `${r.title || 'Untitled'}${r.tags?.length ? ` — ${r.tags.join(', ')}` : ''}`)
        .join('; ')}`;
    }

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 1024,
      system,
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
    });

    const text = response.content.filter((b) => b.type === 'text').map((b) => b.text).join('\n');
    res.json({ reply: text, stopReason: response.stop_reason });
  } catch (err) {
    console.error('chat error', err);
    res.status(500).json({ error: err.message || 'Chat request failed' });
  }
});

// ---------- Recipe link importer ----------
app.post('/api/import-recipe', async (req, res) => {
  try {
    const { url } = req.body || {};
    if (!url || typeof url !== 'string') {
      return res.status(400).json({ error: 'url is required' });
    }

    const schema = {
      type: 'object',
      properties: {
        title: { type: 'string' },
        ingredients: { type: 'array', items: { type: 'string' } },
        method: { type: 'string' },
        tags: { type: 'array', items: { type: 'string' } },
      },
      required: ['title', 'ingredients', 'method', 'tags'],
      additionalProperties: false,
    };

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      system:
        'You extract recipes from web pages for a private recipe app. Fetch the given URL, then extract the ' +
        'recipe as JSON. Ingredients should be one per line item with quantity if stated. Method should be ' +
        'numbered or newline-separated steps. Tags are short lowercase keywords (e.g. "quick", "dinner", "spicy"). ' +
        "If the page is a video (e.g. TikTok) without a written recipe, do your best from the caption/description " +
        'and note any uncertainty inline in the method field. Never fabricate ingredients that are not implied by the source.',
      tools: [{ type: 'web_fetch_20260209', name: 'web_fetch', max_uses: 3 }],
      output_config: { format: { type: 'json_schema', schema } },
      messages: [
        {
          role: 'user',
          content: `Recipe URL: ${url}\n\nFetch this page and extract the recipe.`,
        },
      ],
    });

    const recipe = firstJsonTextBlock(response.content);
    res.json(recipe);
  } catch (err) {
    console.error('import-recipe error', err);
    res.status(500).json({ error: err.message || 'Recipe import failed' });
  }
});

// ---------- AI meal-plan suggestion ----------
app.post('/api/suggest-mealplan', async (req, res) => {
  try {
    const { recipes, preferences } = req.body || {};
    if (!Array.isArray(recipes) || recipes.length === 0) {
      return res.status(400).json({ error: 'recipes array is required' });
    }

    const schema = {
      type: 'object',
      properties: {
        plan: {
          type: 'array',
          items: { type: 'array', items: { type: 'integer' } },
        },
        notes: { type: 'string' },
      },
      required: ['plan', 'notes'],
      additionalProperties: false,
    };

    const recipeList = recipes
      .map((r) => `id=${r.id} | ${r.title || 'Untitled'} | tags: ${(r.tags || []).join(', ') || 'none'}`)
      .join('\n');

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 1536,
      thinking: { type: 'adaptive' },
      system:
        'You are a meal-planning assistant for a private recipe app. Assign recipes to a 7-day week ' +
        '(Monday through Sunday) using ONLY the recipe IDs provided. Aim for variety (avoid repeating the ' +
        'same recipe on consecutive days when there are enough options) and a reasonable mix of tags. ' +
        "It's fine to leave a day empty (empty array) if there aren't enough suitable recipes, and fine to " +
        'assign more than one recipe to a day. Return exactly 7 arrays in `plan`, one per day starting Monday.',
      output_config: { format: { type: 'json_schema', schema } },
      messages: [
        {
          role: 'user',
          content:
            `Available recipes:\n${recipeList}\n\n` +
            (preferences ? `User preferences: ${preferences}\n\n` : '') +
            'Suggest a week plan.',
        },
      ],
    });

    const plan = firstJsonTextBlock(response.content);
    res.json(plan);
  } catch (err) {
    console.error('suggest-mealplan error', err);
    res.status(500).json({ error: err.message || 'Meal plan suggestion failed' });
  }
});

// ---------- Smart grocery-list merge ----------
app.post('/api/smart-groceries', async (req, res) => {
  try {
    const { items } = req.body || {};
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items array is required' });
    }

    const schema = {
      type: 'object',
      properties: {
        items: {
          type: 'array',
          items: {
            type: 'object',
            properties: { name: { type: 'string' }, done: { type: 'boolean' } },
            required: ['name', 'done'],
            additionalProperties: false,
          },
        },
      },
      required: ['items'],
      additionalProperties: false,
    };

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 1536,
      system:
        'You clean up grocery shopping lists. Combine duplicate or near-duplicate ingredients (e.g. "2 onions" + ' +
        '"1 onion" -> "3 onions"; "garlic clove" + "cloves garlic" -> one entry), sum quantities only when units ' +
        'clearly match, and keep entries you cannot confidently merge separate rather than guessing. Preserve ' +
        'a reasonable shopping-list phrasing. If any of the merged source items was checked off ("done": true), ' +
        'mark the merged item done only if ALL of its sources were done.',
      output_config: { format: { type: 'json_schema', schema } },
      messages: [
        {
          role: 'user',
          content: `Current list:\n${JSON.stringify(items)}\n\nReturn the cleaned-up list.`,
        },
      ],
    });

    const merged = firstJsonTextBlock(response.content);
    res.json(merged);
  } catch (err) {
    console.error('smart-groceries error', err);
    res.status(500).json({ error: err.message || 'Smart merge failed' });
  }
});

app.get('/api/health', (_req, res) => res.json({ ok: true, model: MODEL }));

app.listen(PORT, () => {
  console.log(`Perano Cook AI backend listening on :${PORT} (model: ${MODEL})`);
});
