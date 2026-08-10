
// Simple local DB using IndexedDB for blobs & arrays
const DB_NAME = 'perano-cook-db';
const DB_VERSION = 1;
let db;

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('recipes')) db.createObjectStore('recipes', { keyPath: 'id', autoIncrement: true });
      if (!db.objectStoreNames.contains('planner')) db.createObjectStore('planner', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('groceries')) db.createObjectStore('groceries', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('voices')) db.createObjectStore('voices', { keyPath: 'id' }); // {id: recipeId, notes: [Blob,...]}
    };
    req.onsuccess = () => { db = req.result; resolve(db); };
    req.onerror   = () => reject(req.error);
  });
}

function tx(store, mode='readonly') {
  return db.transaction(store, mode).objectStore(store);
}

// ---------- UI helpers ----------
const tabs = document.querySelectorAll('nav.tabs button');
const sections = {
  recipes: document.getElementById('tab-recipes'),
  add: document.getElementById('tab-add'),
  planner: document.getElementById('tab-planner'),
  groceries: document.getElementById('tab-groceries'),
  assistant: document.getElementById('tab-assistant'),
  settings: document.getElementById('tab-settings'),
};

tabs.forEach(btn => btn.addEventListener('click', () => {
  tabs.forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  Object.values(sections).forEach(s => s.classList.add('hidden'));
  sections[btn.dataset.tab].classList.remove('hidden');
  if (btn.dataset.tab === 'recipes') renderRecipes();
  if (btn.dataset.tab === 'planner') renderWeek();
  if (btn.dataset.tab === 'groceries') renderGroceries();
  if (btn.dataset.tab === 'settings') loadAiSettings();
}));

// ---------- AI backend helper ----------
function getAiBase() {
  return (localStorage.getItem('ai-backend-url') || '').replace(/\/+$/, '');
}

async function aiFetch(path, body) {
  const res = await fetch(`${getAiBase()}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data;
}

function loadAiSettings() {
  const el = document.getElementById('ai-backend-url');
  if (el) el.value = getAiBase();
}

// ---------- Recipes ----------
const listEl = document.getElementById('recipes-list');
const searchEl = document.getElementById('search');

async function getAllRecipes() {
  return new Promise((resolve) => {
    const out = [];
    const cursor = tx('recipes').openCursor();
    cursor.onsuccess = (e) => {
      const c = e.target.result;
      if (c) { out.push(c.value); c.continue(); } else resolve(out);
    };
  });
}

function blobToDataURL(blob) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.readAsDataURL(blob);
  });
}

async function renderRecipes() {
  const q = (searchEl.value || '').toLowerCase();
  const items = await getAllRecipes();
  const filtered = items.filter(r => {
    const hay = [r.title, r.link, r.tags?.join(','), r.ingredients?.join(',')].join(' ').toLowerCase();
    return hay.includes(q);
  });
  listEl.innerHTML = '';
  for (const r of filtered.reverse()) {
    const card = document.createElement('div'); card.className='card';
    const title = document.createElement('h3'); title.textContent = r.title || 'Untitled';
    const small = document.createElement('div'); small.className='small'; small.textContent = r.link || '';
    const tags = document.createElement('div');
    (r.tags||[]).forEach(t => {
      const b = document.createElement('span'); b.className='badge'; b.textContent = t.trim(); tags.appendChild(b);
    });
    const actions = document.createElement('div'); actions.className='actions';
    const btnView = document.createElement('button'); btnView.className='ghost'; btnView.textContent='Open';
    const btnDelete = document.createElement('button'); btnDelete.className='ghost'; btnDelete.textContent='Delete';
    const btnVoice = document.createElement('button'); btnVoice.className='ghost'; btnVoice.textContent='Voice Note';
    actions.append(btnView, btnVoice, btnDelete);
    card.append(title, small, tags, actions);
    if (r.photo) {
      const img = document.createElement('img'); img.style.width='100%'; img.style.borderRadius='10px'; img.style.marginTop='8px';
      try { img.src = await blobToDataURL(r.photo); } catch {}
      card.appendChild(img);
    }
    listEl.appendChild(card);

    btnView.onclick = () => openRecipeModal(r);
    btnDelete.onclick = async () => { await deleteRecipe(r.id); renderRecipes(); };
    btnVoice.onclick = () => voiceNoteForRecipe(r.id);
  }
}
searchEl.addEventListener('input', () => renderRecipes());

async function saveRecipe(data) {
  return new Promise((resolve, reject) => {
    const req = tx('recipes', 'readwrite').add(data);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function updateRecipe(id, patch) {
  const r = await getRecipe(id);
  Object.assign(r, patch);
  return new Promise((resolve, reject) => {
    const req = tx('recipes', 'readwrite').put(r);
    req.onsuccess = () => resolve(true);
    req.onerror = () => reject(req.error);
  });
}

function getRecipe(id) {
  return new Promise((resolve) => {
    const req = tx('recipes').get(id);
    req.onsuccess = () => resolve(req.result);
  });
}

function deleteRecipe(id) {
  return new Promise((resolve) => {
    const req = tx('recipes', 'readwrite').delete(id);
    req.onsuccess = () => resolve(true);
  });
}

// Add form
const titleEl = document.getElementById('r-title');
const linkEl = document.getElementById('r-link');
const ingEl = document.getElementById('r-ingredients');
const methodEl = document.getElementById('r-method');
const tagsEl = document.getElementById('r-tags');
const photoEl = document.getElementById('r-photo');
document.getElementById('btn-save').onclick = async () => {
  const tags = (tagsEl.value || '').split(',').map(s=>s.trim()).filter(Boolean);
  const ingredients = (ingEl.value || '').split('\n').map(s=>s.trim()).filter(Boolean);
  const photo = photoEl.files && photoEl.files[0] ? photoEl.files[0] : null;
  const id = await saveRecipe({ title: titleEl.value, link: linkEl.value, ingredients, method: methodEl.value, tags, photo });
  // clear
  [titleEl, linkEl, ingEl, methodEl, tagsEl].forEach(el => el.value='');
  if (photoEl.value) photoEl.value = '';
  alert('Saved!');
  renderRecipes();
};
document.getElementById('btn-clear').onclick = () => {
  [titleEl, linkEl, ingEl, methodEl, tagsEl].forEach(el => el.value='');
  photoEl.value='';
};

// ---------- Recipe modal (view/edit minimal) ----------
function openRecipeModal(r) {
  const wrap = document.createElement('div');
  Object.assign(wrap.style, { position:'fixed', inset:'0', background:'rgba(0,0,0,0.4)', display:'flex', alignItems:'center', justifyContent:'center', zIndex:'99' });
  const box = document.createElement('div'); box.className='card'; box.style.maxWidth='680px'; box.style.width='92%'; box.style.maxHeight='90vh'; box.style.overflow='auto';
  box.innerHTML = `
    <h2>${r.title || 'Untitled'}</h2>
    ${r.link ? `<p><a href="${r.link}" target="_blank">${r.link}</a></p>` : ''}
    <h4>Ingredients</h4>
    <ul>${(r.ingredients||[]).map(i=>`<li>${i}</li>`).join('')}</ul>
    <h4>Method / Notes</h4>
    <p>${(r.method||'').replace(/\n/g,'<br/>')}</p>
    <div class="actions">
      <button class="ghost" id="m-add-to-planner">Add to Planner</button>
      <button class="ghost" id="m-close">Close</button>
    </div>
  `;
  wrap.appendChild(box);
  document.body.appendChild(wrap);
  document.getElementById('m-close').onclick = () => wrap.remove();
  document.getElementById('m-add-to-planner').onclick = async () => {
    await addToPlannerPrompt(r.id);
    alert('Added to planner');
  };
}

// ---------- Voice notes (per recipe) ----------
async function voiceNoteForRecipe(recipeId) {
  if (!navigator.mediaDevices || !window.MediaRecorder) { alert('Voice recording not supported in this browser.'); return; }
  const stream = await navigator.mediaDevices.getUserMedia({ audio:true });
  const rec = new MediaRecorder(stream);
  const chunks = [];
  rec.ondataavailable = (e) => chunks.push(e.data);
  rec.onstop = async () => {
    const blob = new Blob(chunks, { type: 'audio/webm' });
    // store in voices store: record {id: recipeId, notes: [Blob...]}
    const row = await new Promise((resolve)=>{
      const req = tx('voices').get(recipeId);
      req.onsuccess = ()=> resolve(req.result || {id: recipeId, notes: []});
    });
    row.notes.push(blob);
    await new Promise((resolve)=>{
      const req = tx('voices','readwrite').put(row);
      req.onsuccess = ()=> resolve(true);
    });
    alert('Voice note saved');
  };
  rec.start();
  const stop = confirm('Recording… Press OK to stop');
  if (stop) rec.stop(); else rec.stop();
}

// ---------- Planner ----------
const weekEl = document.getElementById('week-grid');
const DAYS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

async function getPlanner() {
  return new Promise((resolve)=>{
    const req = tx('planner').get('week');
    req.onsuccess = ()=> resolve(req.result?.data || Array(7).fill(null).map(()=>[]));
  });
}
async function setPlanner(data) {
  return new Promise((resolve)=>{
    const req = tx('planner','readwrite').put({id:'week', data});
    req.onsuccess = ()=> resolve(true);
  });
}

async function renderWeek() {
  const data = await getPlanner();
  weekEl.innerHTML = '';
  data.forEach((dayList, i) => {
    const d = document.createElement('div'); d.className='day';
    const h = document.createElement('h4'); h.textContent = DAYS[i];
    d.appendChild(h);
    dayList.forEach(id => {
      const chip = document.createElement('div'); chip.className='recipe-chip'; chip.textContent = `#${id}`;
      chip.style.cursor='pointer';
      chip.onclick = async () => { const r = await getRecipe(id); if (r) openRecipeModal(r); };
      d.appendChild(chip);
    });
    weekEl.appendChild(d);
  });
}

async function addToPlannerPrompt(recipeId) {
  const day = prompt('Add to which day? (Mon/Tue/Wed/Thu/Fri/Sat/Sun)');
  const idx = DAYS.findIndex(d => d.toLowerCase() === (day||'').trim().slice(0,3).toLowerCase());
  if (idx<0) return;
  const data = await getPlanner();
  data[idx].push(recipeId);
  await setPlanner(data);
  renderWeek();
}

document.getElementById('btn-plan-add').onclick = async () => {
  const all = await getAllRecipes();
  if (all.length === 0) { alert('No recipes yet. Add one first.'); return; }
  const idStr = prompt(`Enter recipe ID to add (available: ${all.map(r=>r.id+':'+(r.title||'Untitled')).join(', ')})`);
  const id = Number(idStr);
  if (!id || !all.find(r=>r.id===id)) { alert('Invalid recipe ID'); return; }
  await addToPlannerPrompt(id);
};
document.getElementById('btn-plan-clear').onclick = async () => {
  if (!confirm('Clear entire week?')) return;
  await setPlanner(Array(7).fill(null).map(()=>[]));
  renderWeek();
};

// ---------- Groceries ----------
async function setGroceries(items) {
  return new Promise((resolve)=>{
    const req = tx('groceries','readwrite').put({id:'list', items});
    req.onsuccess = ()=> resolve(true);
  });
}
async function getGroceries() {
  return new Promise((resolve)=>{
    const req = tx('groceries').get('list');
    req.onsuccess = ()=> resolve(req.result?.items || []);
  });
}
async function renderGroceries() {
  const items = await getGroceries();
  const ul = document.getElementById('groceries-list');
  ul.innerHTML = '';
  items.forEach((it, idx) => {
    const li = document.createElement('li');
    const cb = document.createElement('input'); cb.type='checkbox'; cb.checked = !!it.done;
    cb.onchange = async () => { it.done = cb.checked; items[idx]=it; await setGroceries(items); };
    const span = document.createElement('span'); span.textContent = it.name;
    li.append(cb, span);
    ul.appendChild(li);
  });
}

document.getElementById('btn-groceries-clear').onclick = async () => {
  await setGroceries([]);
  renderGroceries();
};

document.getElementById('btn-groceries-export').onclick = async () => {
  const items = await getGroceries();
  const text = items.map(i => (i.done?'[x] ':'[ ] ') + i.name).join('\n');
  const blob = new Blob([text], {type:'text/plain'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href=url; a.download='groceries.txt'; a.click();
  URL.revokeObjectURL(url);
};

document.getElementById('btn-generate-groceries').onclick = async () => {
  const data = await getPlanner();
  const ids = [...new Set(data.flat())];
  const all = await Promise.all(ids.map(id => getRecipe(id)));
  const lines = all.flatMap(r => (r?.ingredients||[]));
  const normalized = lines.map(s => s.trim()).filter(Boolean);
  // De-duplicate naive
  const map = new Map();
  normalized.forEach(line => {
    const key = line.toLowerCase();
    if (!map.has(key)) map.set(key, { name: line, done:false });
  });
  await setGroceries([...map.values()]);
  alert('Groceries generated from planner.');
  renderGroceries();
};

// ---------- Backup / Restore ----------
document.getElementById('btn-backup').onclick = async () => {
  const recipes = await getAllRecipes();
  const planner = await getPlanner();
  const groceries = await getGroceries();
  const data = { recipes: recipes.map(r => ({...r, photo: undefined })), planner, groceries, note:'Photos & voice notes are not included in this JSON backup.' };
  const blob = new Blob([JSON.stringify(data, null, 2)], {type:'application/json'});
  const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download='perano-cook-backup.json'; a.click();
};

document.getElementById('btn-restore').onclick = () => {
  document.getElementById('backup-file').click();
};
document.getElementById('backup-file').addEventListener('change', async (e) => {
  const file = e.target.files[0]; if (!file) return;
  const text = await file.text();
  try {
    const data = JSON.parse(text);
    // restore recipes without photos
    const txw = db.transaction(['recipes','planner','groceries'],'readwrite');
    const recStore = txw.objectStore('recipes');
    const planStore = txw.objectStore('planner');
    const grocStore = txw.objectStore('groceries');
    // Clear then put
    recStore.clear();
    planStore.clear();
    grocStore.clear();
    (data.recipes||[]).forEach(r => recStore.add(r));
    planStore.put({id:'week', data: data.planner || Array(7).fill(null).map(()=>[])});
    grocStore.put({id:'list', items: data.groceries || []});
    txw.oncomplete = () => { alert('Restore complete'); renderRecipes(); renderWeek(); renderGroceries(); };
  } catch(err) {
    alert('Invalid backup file');
  }
});

// ---------- AI Settings ----------
document.getElementById('btn-ai-save').onclick = () => {
  const val = document.getElementById('ai-backend-url').value.trim();
  localStorage.setItem('ai-backend-url', val);
  document.getElementById('ai-status').textContent = 'Saved.';
};
document.getElementById('btn-ai-test').onclick = async () => {
  const statusEl = document.getElementById('ai-status');
  statusEl.textContent = 'Checking…';
  try {
    const res = await fetch(`${getAiBase()}/api/health`);
    const data = await res.json();
    statusEl.textContent = res.ok ? `Connected (model: ${data.model})` : 'Backend reachable but unhealthy.';
  } catch (err) {
    statusEl.textContent = `Could not reach backend: ${err.message}`;
  }
};

// ---------- AI recipe import ----------
document.getElementById('btn-import-link').onclick = async () => {
  const statusEl = document.getElementById('import-status');
  const link = linkEl.value.trim();
  if (!link) { statusEl.textContent = 'Paste a link first.'; return; }
  statusEl.textContent = 'Fetching and reading the recipe…';
  try {
    const recipe = await aiFetch('/api/import-recipe', { url: link });
    if (recipe.title) titleEl.value = recipe.title;
    if (Array.isArray(recipe.ingredients)) ingEl.value = recipe.ingredients.join('\n');
    if (recipe.method) methodEl.value = recipe.method;
    if (Array.isArray(recipe.tags)) tagsEl.value = recipe.tags.join(', ');
    statusEl.textContent = 'Imported — review before saving.';
  } catch (err) {
    statusEl.textContent = `Import failed: ${err.message}`;
  }
};

// ---------- AI meal-plan suggestion ----------
document.getElementById('btn-suggest-week').onclick = async () => {
  const statusEl = document.getElementById('suggest-week-status');
  const all = await getAllRecipes();
  if (all.length === 0) { statusEl.textContent = 'No recipes yet. Add some first.'; return; }
  statusEl.textContent = 'Planning your week…';
  try {
    const recipes = all.map(r => ({ id: r.id, title: r.title, tags: r.tags || [] }));
    const result = await aiFetch('/api/suggest-mealplan', { recipes });
    const plan = (result.plan || []).slice(0, 7);
    while (plan.length < 7) plan.push([]);
    const validIds = new Set(all.map(r => r.id));
    const cleaned = plan.map(day => (Array.isArray(day) ? day : []).filter(id => validIds.has(id)));
    await setPlanner(cleaned);
    renderWeek();
    statusEl.textContent = result.notes || 'Week planned.';
  } catch (err) {
    statusEl.textContent = `Couldn't plan the week: ${err.message}`;
  }
};

// ---------- AI smart grocery merge ----------
document.getElementById('btn-groceries-smart-merge').onclick = async () => {
  const statusEl = document.getElementById('smart-merge-status');
  const items = await getGroceries();
  if (items.length === 0) { statusEl.textContent = 'Grocery list is empty.'; return; }
  statusEl.textContent = 'Merging and tidying the list…';
  try {
    const result = await aiFetch('/api/smart-groceries', { items });
    if (Array.isArray(result.items)) {
      await setGroceries(result.items);
      renderGroceries();
      statusEl.textContent = `Merged ${items.length} items into ${result.items.length}.`;
    }
  } catch (err) {
    statusEl.textContent = `Smart merge failed: ${err.message}`;
  }
};

// ---------- AI chat assistant ----------
const chatLogEl = document.getElementById('chat-log');
const chatInputEl = document.getElementById('chat-input');
const chatStatusEl = document.getElementById('chat-status');
let chatHistory = [];

function renderChatMessage(role, text) {
  const bubble = document.createElement('div');
  bubble.className = `chat-bubble chat-${role}`;
  bubble.textContent = text;
  chatLogEl.appendChild(bubble);
  chatLogEl.scrollTop = chatLogEl.scrollHeight;
}

async function sendChatMessage() {
  const text = chatInputEl.value.trim();
  if (!text) return;
  chatInputEl.value = '';
  chatHistory.push({ role: 'user', content: text });
  renderChatMessage('user', text);
  chatStatusEl.textContent = 'Thinking…';
  try {
    const all = await getAllRecipes();
    const recipeContext = all.map(r => ({ title: r.title, tags: r.tags || [] }));
    const result = await aiFetch('/api/chat', { messages: chatHistory, recipeContext });
    chatHistory.push({ role: 'assistant', content: result.reply });
    renderChatMessage('assistant', result.reply);
    chatStatusEl.textContent = '';
  } catch (err) {
    chatStatusEl.textContent = `Error: ${err.message}`;
  }
}
document.getElementById('btn-chat-send').onclick = sendChatMessage;
chatInputEl.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') sendChatMessage();
});

// ---------- Init ----------
openDB().then(() => {
  renderRecipes();
  renderWeek();
  renderGroceries();
  loadAiSettings();
});
