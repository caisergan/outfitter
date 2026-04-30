const BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

function getToken() {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("outfitter_token");
}

async function apiFetch(path, options = {}) {
  const token = getToken();
  const headers = {
    ...options.headers,
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  if (!(options.body instanceof FormData) && options.body && typeof options.body === "object" && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }

  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers,
    body:
      options.body instanceof FormData
        ? options.body
        : options.body
        ? JSON.stringify(options.body)
        : undefined,
  });

  if (res.status === 401) {
    if (typeof window !== "undefined") {
      localStorage.removeItem("outfitter_token");
      window.location.href = "/login";
    }
    throw new Error("Unauthorized");
  }

  if (res.status === 204) return null;

  const data = await res.json();

  if (!res.ok) {
    const detail = data?.detail;
    const message =
      typeof detail === "string"
        ? detail
        : detail?.error?.message || detail?.message || `HTTP ${res.status}`;
    const err = new Error(message);
    err.status = res.status;
    err.detail = detail ?? null;
    throw err;
  }

  return data;
}

// ── Auth ────────────────────────────────────────────────────────────────────

export async function login(email, password) {
  const body = new URLSearchParams({ username: email, password });
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  if (!res.ok) {
    const data = await res.json();
    throw new Error(data?.detail || "Login failed");
  }
  return res.json();
}

export async function signup(email, password) {
  return apiFetch("/auth/signup", { method: "POST", body: { email, password } });
}

export async function getMe() {
  return apiFetch("/auth/me");
}

// ── Health ──────────────────────────────────────────────────────────────────

export async function healthCheck() {
  const res = await fetch(`${BASE_URL}/health`);
  return res.json();
}

// ── Catalog ─────────────────────────────────────────────────────────────────

export async function getCatalogFilterOptions() {
  return apiFetch("/catalog/filter-options");
}

export async function searchCatalog(params = {}) {
  const q = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== null && v !== undefined && v !== "") q.set(k, v);
  });
  return apiFetch(`/catalog/search?${q.toString()}`);
}

export async function getSimilarItems(itemId, limit = 10, source = "catalog") {
  return apiFetch(`/catalog/similar/${itemId}?limit=${limit}&source=${source}`);
}

export async function requestCatalogImageUpload(data) {
  return apiFetch("/catalog/images/upload-url", { method: "POST", body: data });
}

export async function createCatalogItem(data) {
  return apiFetch("/catalog/items", { method: "POST", body: data });
}

export async function updateCatalogItem(itemId, data) {
  return apiFetch(`/catalog/items/${itemId}`, { method: "PATCH", body: data });
}

// ── Wardrobe ─────────────────────────────────────────────────────────────────

export async function listWardrobe(params = {}) {
  const q = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== null && v !== undefined && v !== "") q.set(k, v);
  });
  return apiFetch(`/wardrobe?${q.toString()}`);
}

export async function tagWardrobeItem(file) {
  const form = new FormData();
  form.append("file", file);
  return apiFetch("/wardrobe/tag", { method: "POST", body: form });
}

export async function createWardrobeItem(data) {
  return apiFetch("/wardrobe", { method: "POST", body: data });
}

export async function deleteWardrobeItem(itemId) {
  return apiFetch(`/wardrobe/${itemId}`, { method: "DELETE" });
}

// ── Outfits ──────────────────────────────────────────────────────────────────

export async function suggestOutfits(data) {
  return apiFetch("/outfits/suggest", { method: "POST", body: data });
}

export async function listOutfits() {
  return apiFetch("/outfits");
}

export async function saveOutfit(data) {
  return apiFetch("/outfits", { method: "POST", body: data });
}

export async function deleteOutfit(outfitId) {
  return apiFetch(`/outfits/${outfitId}`, { method: "DELETE" });
}

// ── Try-On ───────────────────────────────────────────────────────────────────

export async function submitTryOn(data) {
  return apiFetch("/tryon/submit", { method: "POST", body: data });
}

export async function getTryOnStatus(jobId) {
  return apiFetch(`/tryon/status/${jobId}`);
}

// ── Playground ───────────────────────────────────────────────────────────────

export async function generatePlaygroundImage(payload) {
  // payload: { catalog_item_ids: string[], system_prompt: string, user_prompt?: string,
  //            template_id?: string, persona_id?: string,
  //            size?: string, quality?: string, n?: number }
  return apiFetch("/playground/generate-image", { method: "POST", body: payload });
}

export async function fetchPlaygroundSystemPrompt() {
  return apiFetch("/playground/system-prompt");
}

export async function fetchPlaygroundTemplates() {
  return apiFetch("/playground/templates");
}

export async function fetchPlaygroundPersonas(gender) {
  const q = gender ? `?gender=${encodeURIComponent(gender)}` : "";
  return apiFetch(`/playground/personas${q}`);
}

export async function fetchPlaygroundRuns({ limit, cursor } = {}) {
  const q = new URLSearchParams();
  if (limit) q.set("limit", limit);
  if (cursor) q.set("cursor", cursor);
  const qs = q.toString();
  return apiFetch(`/playground/runs${qs ? `?${qs}` : ""}`);
}

export async function fetchPlaygroundRun(runId) {
  return apiFetch(`/playground/runs/${runId}`);
}

export async function getCatalogItem(itemId) {
  return apiFetch(`/catalog/items/${itemId}`);
}

// ── Admin: prompt library CRUD ──────────────────────────────────────────────

export async function patchPlaygroundSystemPrompt(payload) {
  return apiFetch("/playground/system-prompt", { method: "PATCH", body: payload });
}

export async function listPlaygroundTemplatesAdmin() {
  return apiFetch("/playground/templates?include_inactive=true");
}

export async function createPlaygroundTemplate(payload) {
  return apiFetch("/playground/templates", { method: "POST", body: payload });
}

export async function patchPlaygroundTemplate(id, payload) {
  return apiFetch(`/playground/templates/${id}`, { method: "PATCH", body: payload });
}

export async function deletePlaygroundTemplate(id) {
  return apiFetch(`/playground/templates/${id}`, { method: "DELETE" });
}

export async function listPlaygroundPersonasAdmin() {
  return apiFetch("/playground/personas?include_inactive=true");
}

export async function createPlaygroundPersona(payload) {
  return apiFetch("/playground/personas", { method: "POST", body: payload });
}

export async function patchPlaygroundPersona(id, payload) {
  return apiFetch(`/playground/personas/${id}`, { method: "PATCH", body: payload });
}

export async function deletePlaygroundPersona(id) {
  return apiFetch(`/playground/personas/${id}`, { method: "DELETE" });
}
