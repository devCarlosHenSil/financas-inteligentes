/**
 * Cloudflare Worker — Proxy BRAPI
 *
 * Rotas disponíveis:
 *   GET /brapiQuoteList   → /quote/list
 *   GET /brapiQuote       → /quote/:symbols  (param: symbols)
 *   GET /brapiCurrency    → /v2/currency      (param: currency)
 *   GET /brapiCrypto      → /v2/crypto        (params: coin, currency)
 *
 * Secret necessário (configurar via wrangler):
 *   npx wrangler secret put BRAPI_TOKEN
 */

const BRAPI_BASE_URL = "https://brapi.dev/api";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response("", { status: 204, headers: corsHeaders });
    }

    if (request.method !== "GET") {
      return jsonResponse({ error: true, message: "Method not allowed" }, 405);
    }

    if (!env.BRAPI_TOKEN) {
      return jsonResponse({ error: true, message: "BRAPI_TOKEN not configured" }, 500);
    }

    const incoming = new URL(request.url);
    const route = incoming.pathname.replace(/^\//, "");

    let brapiPath = null;

    if (route === "brapiQuoteList") {
      brapiPath = "/quote/list";
    } else if (route === "brapiQuote") {
      const symbols = incoming.searchParams.get("symbols");
      if (!symbols) {
        return jsonResponse({ error: true, message: "symbols is required" }, 400);
      }
      brapiPath = `/quote/${encodeURIComponent(symbols)}`;
    } else if (route === "brapiCurrency") {
      const currency = incoming.searchParams.get("currency");
      if (!currency) {
        return jsonResponse({ error: true, message: "currency is required" }, 400);
      }
      brapiPath = "/v2/currency";
    } else if (route === "brapiCrypto") {
      const coin = incoming.searchParams.get("coin");
      const currency = incoming.searchParams.get("currency");
      if (!coin || !currency) {
        return jsonResponse({ error: true, message: "coin and currency are required" }, 400);
      }
      brapiPath = "/v2/crypto";
    } else {
      return jsonResponse({ error: true, message: "Not found" }, 404);
    }

    const brapiUrl = new URL(`${BRAPI_BASE_URL}${brapiPath}`);
    incoming.searchParams.forEach((value, key) => {
      if (route === "brapiQuote" && key === "symbols") return;
      if (value.trim() !== "") {
        brapiUrl.searchParams.set(key, value);
      }
    });

    try {
      const response = await fetch(brapiUrl.toString(), {
        headers: {
          Authorization: `Bearer ${env.BRAPI_TOKEN}`,
        },
      });

      // Trata 401/403 da BRAPI de forma padronizada.
      // O cliente Flutter detecta via _isBrapiFeatureUnavailable e ativa o fallback.
      if (response.status === 401 || response.status === 403) {
        return jsonResponse(
          {
            error: true,
            message: "Recurso indisponível no plano atual",
            code: "FEATURE_NOT_AVAILABLE",
          },
          200 // retorna 200 para que o Flutter faça o parse normalmente
        );
      }

      const body = await response.text();
      const headers = new Headers(corsHeaders);
      const contentType = response.headers.get("content-type");
      if (contentType) {
        headers.set("Content-Type", contentType);
      }
      return new Response(body, { status: response.status, headers });
    } catch (err) {
      return jsonResponse({ error: true, message: "Brapi request failed" }, 502);
    }
  },
};
