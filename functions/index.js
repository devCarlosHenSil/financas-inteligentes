const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const BRAPI_BASE_URL = "https://brapi.dev/api";
const brapiToken = defineSecret("BRAPI_TOKEN");

function withCors(handler) {
  return async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET,OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "GET") {
      res.status(405).json({ error: true, message: "Method not allowed" });
      return;
    }

    return handler(req, res);
  };
}

async function callBrapi(res, path, params) {
  const token = brapiToken.value();
  if (!token) {
    res.status(500).json({
      error: true,
      message: "BRAPI_TOKEN not configured",
    });
    return;
  }

  const url = new URL(`${BRAPI_BASE_URL}${path}`);
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      url.searchParams.set(key, String(value));
    }
  });

  try {
    const response = await fetch(url.toString(), {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    const text = await response.text();

    const contentType = response.headers.get("content-type");
    if (contentType) {
      res.set("Content-Type", contentType);
    }

    res.status(response.status).send(text);
  } catch (err) {
    logger.error("Brapi proxy error", err);
    res.status(502).json({ error: true, message: "Brapi request failed" });
  }
}

exports.brapiQuoteList = onRequest(
  { secrets: [brapiToken] },
  withCors(async (req, res) => {
    const { type, search, limit, sortBy, sortOrder } = req.query;
    const parsedLimit = Number(limit);
    const safeLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 200)
      : undefined;

    await callBrapi(res, "/quote/list", {
      type,
      search,
      limit: safeLimit,
      sortBy,
      sortOrder,
    });
  })
);

exports.brapiQuote = onRequest(
  { secrets: [brapiToken] },
  withCors(async (req, res) => {
    const { symbols, range, interval, fundamental, dividends } = req.query;
    if (!symbols || String(symbols).trim() === "") {
      res.status(400).json({ error: true, message: "symbols is required" });
      return;
    }

    await callBrapi(res, `/quote/${encodeURIComponent(symbols)}`, {
      range,
      interval,
      fundamental,
      dividends,
    });
  })
);

exports.brapiCurrency = onRequest(
  { secrets: [brapiToken] },
  withCors(async (req, res) => {
    const { currency } = req.query;
    if (!currency || String(currency).trim() === "") {
      res.status(400).json({ error: true, message: "currency is required" });
      return;
    }

    await callBrapi(res, "/v2/currency", { currency });
  })
);

exports.brapiCrypto = onRequest(
  { secrets: [brapiToken] },
  withCors(async (req, res) => {
    const { coin, currency } = req.query;
    if (!coin || !currency) {
      res.status(400).json({ error: true, message: "coin and currency are required" });
      return;
    }

    await callBrapi(res, "/v2/crypto", { coin, currency });
  })
);
