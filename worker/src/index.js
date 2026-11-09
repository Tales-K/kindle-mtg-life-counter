// Worker que serve os arquivos do plugin (assets estaticos) so para quem manda o token certo.

const encoder = new TextEncoder();

async function digest(text) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(text)));
}

// Compara dois textos em tempo constante (via hash de tamanho fixo).
async function safeEqual(a, b) {
  const [da, db] = await Promise.all([digest(a), digest(b)]);
  let diff = 0;
  for (let i = 0; i < da.length; i++) diff |= da[i] ^ db[i];
  return diff === 0;
}

function unauthorized() {
  return new Response("unauthorized", {
    status: 401,
    headers: { "WWW-Authenticate": "Bearer", "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request, env) {
    const secret = env.UPDATE_TOKEN;
    const header = request.headers.get("Authorization") || "";
    const given = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!secret || !given || !(await safeEqual(given, secret))) return unauthorized();

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
    }

    const path = new URL(request.url).pathname;
    if (!path.startsWith("/v1/") || path.endsWith("/") || path.includes("//")) {
      return new Response("not found", { status: 404 });
    }

    const res = await env.ASSETS.fetch(request);
    if (res.status !== 200) return new Response("not found", { status: 404 });
    if (path === "/v1/manifest.json") {
      const headers = new Headers(res.headers);
      headers.set("Cache-Control", "no-store");
      return new Response(res.body, { status: 200, headers });
    }
    return res;
  },
};
