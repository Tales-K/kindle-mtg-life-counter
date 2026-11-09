import test from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";

const TOKEN = "t0ken-abcdefghijklmnopqrstuvwxyz";
const files = {
  "/v1/manifest.json": '{"version":2,"files":[]}',
  "/v1/core/game.lua": "game code",
};

function env() {
  return {
    UPDATE_TOKEN: TOKEN,
    ASSETS: {
      async fetch(request) {
        const path = new URL(request.url).pathname;
        if (path in files) return new Response(files[path], { status: 200 });
        return new Response("not found", { status: 404 });
      },
    },
  };
}

function req(path, { method = "GET", token = TOKEN } = {}) {
  const headers = token === null ? {} : { Authorization: `Bearer ${token}` };
  return new Request(`https://kindle.example.workers.dev${path}`, { method, headers });
}

test("no token returns 401", async () => {
  const res = await worker.fetch(req("/v1/manifest.json", { token: null }), env());
  assert.equal(res.status, 401);
});

test("wrong token returns 401 with the same body as for a missing file", async () => {
  const wrong = await worker.fetch(req("/v1/manifest.json", { token: "nope" }), env());
  const missing = await worker.fetch(req("/v1/does/not/exist.lua", { token: "nope" }), env());
  assert.equal(wrong.status, 401);
  assert.equal(missing.status, 401);
  assert.equal(await wrong.text(), await missing.text());
});

test("token in the url does not authenticate", async () => {
  const res = await worker.fetch(req(`/v1/manifest.json?t=${TOKEN}`, { token: null }), env());
  assert.equal(res.status, 401);
});

test("valid token serves the manifest with no-store", async () => {
  const res = await worker.fetch(req("/v1/manifest.json"), env());
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "no-store");
  assert.equal(await res.text(), files["/v1/manifest.json"]);
});

test("valid token serves other files from assets", async () => {
  const res = await worker.fetch(req("/v1/core/game.lua"), env());
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "game code");
});

test("HEAD is allowed", async () => {
  const res = await worker.fetch(req("/v1/core/game.lua", { method: "HEAD" }), env());
  assert.equal(res.status, 200);
});

test("POST returns 405", async () => {
  const res = await worker.fetch(req("/v1/manifest.json", { method: "POST" }), env());
  assert.equal(res.status, 405);
});

test("path outside /v1/ returns 404", async () => {
  for (const p of ["/", "/v2/manifest.json", "/secret", "/v1"]) {
    const res = await worker.fetch(req(p), env());
    assert.equal(res.status, 404, p);
  }
});

test("directory paths and dotdot return 404", async () => {
  for (const p of ["/v1/", "/v1/core/", "/v1/../etc/passwd", "/v1//core/game.lua"]) {
    const res = await worker.fetch(req(p), env());
    assert.equal(res.status, 404, p);
  }
});

test("missing UPDATE_TOKEN secret denies everything", async () => {
  const e = env();
  delete e.UPDATE_TOKEN;
  const res = await worker.fetch(req("/v1/manifest.json"), e);
  assert.equal(res.status, 401);
});
