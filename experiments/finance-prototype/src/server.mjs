import { createServer } from "node:http";
import { request as httpsRequest } from "node:https";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, normalize, resolve } from "node:path";
import { URL } from "node:url";

const dataDir = process.env.FINANCE_DATA_DIR || resolve(".finance-data");
const publicDir = process.env.FINANCE_PUBLIC_DIR || resolve("experiments/finance-prototype/public");
const addr = process.env.FINANCE_ADDR || "127.0.0.1:8077";
const tellerBaseUrl = process.env.TELLER_API_BASE || "https://api.teller.io";
const tellerProducts = (process.env.TELLER_PRODUCTS || "transactions")
  .split(",")
  .map((product) => product.trim())
  .filter(Boolean);

const contentTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
};

function splitAddr(value) {
  const [host, port] = value.split(":");
  return { host, port: Number.parseInt(port, 10) };
}

function json(response, status, body) {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body, null, 2));
}

function text(response, status, body) {
  response.writeHead(status, { "content-type": "text/plain; charset=utf-8" });
  response.end(body);
}

function dataPath(name) {
  return join(dataDir, name);
}

async function readJson(name, fallback) {
  const path = dataPath(name);
  if (!existsSync(path)) return fallback;
  return JSON.parse(await readFile(path, "utf8"));
}

async function writeJson(name, value) {
  await mkdir(dataDir, { recursive: true });
  await writeFile(dataPath(name), `${JSON.stringify(value, null, 2)}\n`);
}

function tellerConfigured() {
  return Boolean(
    (process.env.TELLER_CERT_PATH || process.env.TELLER_CERT_PEM) &&
      (process.env.TELLER_KEY_PATH || process.env.TELLER_KEY_PEM),
  );
}

function tellerConnectConfigured() {
  return Boolean(process.env.TELLER_APPLICATION_ID);
}

async function tellerCredential(pathName, pemName) {
  if (process.env[pemName]) return process.env[pemName].replaceAll("\\n", "\n");
  return readFile(process.env[pathName], "utf8");
}

async function tellerRequest(path, token, query = {}) {
  const url = new URL(path, tellerBaseUrl);
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, value);
    }
  }

  const cert = await tellerCredential("TELLER_CERT_PATH", "TELLER_CERT_PEM");
  const key = await tellerCredential("TELLER_KEY_PATH", "TELLER_KEY_PEM");

  return new Promise((resolvePromise, reject) => {
    const req = httpsRequest(
      url,
      {
        method: "GET",
        cert,
        key,
        auth: `${token}:`,
        headers: { accept: "application/json" },
      },
      (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => {
          if (res.statusCode < 200 || res.statusCode >= 300) {
            reject(new Error(`Teller ${res.statusCode}: ${body}`));
            return;
          }
          resolvePromise(body ? JSON.parse(body) : null);
        });
      },
    );

    req.on("error", reject);
    req.end();
  });
}

function startDate(transactions) {
  const lookbackDays = Number.parseInt(process.env.FINANCE_LOOKBACK_DAYS || "45", 10);
  const latest = transactions.reduce((current, tx) => {
    if (!tx.date) return current;
    return current && current > tx.date ? current : tx.date;
  }, "");

  const date = latest ? new Date(`${latest}T00:00:00`) : new Date();
  date.setDate(date.getDate() - lookbackDays);
  return date.toISOString().slice(0, 10);
}

function upsertById(existing, incoming) {
  const byId = new Map(existing.map((item) => [item.id, item]));
  for (const item of incoming) {
    byId.set(item.id, item);
  }
  return [...byId.values()];
}

async function readBody(request) {
  return new Promise((resolvePromise, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      body += chunk;
    });
    request.on("end", () => {
      try {
        resolvePromise(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });
    request.on("error", reject);
  });
}

function normalizeEnrollment(enrollment) {
  if (!enrollment.accessToken) {
    throw new Error("Enrollment is missing accessToken.");
  }

  return {
    accessToken: enrollment.accessToken,
    userId: enrollment.userId || null,
    enrollmentId: enrollment.enrollmentId || enrollment.accessToken,
    institutionName: enrollment.institutionName || null,
    environment: enrollment.environment || process.env.TELLER_ENVIRONMENT || "development",
    createdAt: enrollment.createdAt || new Date().toISOString(),
    raw: enrollment.raw || null,
  };
}

async function saveEnrollment(enrollment) {
  const normalized = normalizeEnrollment(enrollment);
  const existing = await readJson("enrollments.json", []);
  const next = new Map(existing.map((item) => [item.enrollmentId || item.accessToken, item]));
  next.set(normalized.enrollmentId || normalized.accessToken, normalized);
  await writeJson("enrollments.json", [...next.values()]);
  return normalized;
}

async function tellerTokens() {
  const envTokens = (process.env.TELLER_ACCESS_TOKENS || "")
    .split(",")
    .map((token) => token.trim())
    .filter(Boolean);
  const storedTokens = (await readJson("enrollments.json", [])).map((enrollment) => enrollment.accessToken);
  return [...new Set([...envTokens, ...storedTokens].filter(Boolean))];
}

async function importTeller() {
  if (!tellerConfigured()) {
    throw new Error(
      "Teller is not configured. Set TELLER_CERT_PATH/TELLER_KEY_PATH or TELLER_CERT_PEM/TELLER_KEY_PEM.",
    );
  }

  const tokens = await tellerTokens();
  if (tokens.length === 0) {
    throw new Error("No Teller access tokens found. Connect an enrollment or set TELLER_ACCESS_TOKENS.");
  }
  const existingTransactions = await readJson("transactions.json", []);
  const importedAccounts = [];
  const importedTransactions = [];
  const from = startDate(existingTransactions);

  for (const token of tokens) {
    const accounts = await tellerRequest("/accounts", token);
    importedAccounts.push(...accounts);

    for (const account of accounts) {
      if (!account.links?.transactions) continue;
      const path = new URL(account.links.transactions).pathname;
      const transactions = await tellerRequest(path, token, { start_date: from });
      importedTransactions.push(...transactions);
    }
  }

  await writeJson("accounts.json", upsertById(await readJson("accounts.json", []), importedAccounts));
  await writeJson("transactions.json", upsertById(existingTransactions, importedTransactions));
  await writeJson("last-import.json", {
    imported_at: new Date().toISOString(),
    provider: "teller",
    accounts: importedAccounts.length,
    transactions: importedTransactions.length,
    start_date: from,
  });

  return {
    accounts: importedAccounts.length,
    transactions: importedTransactions.length,
    start_date: from,
  };
}

async function serveStatic(request, response) {
  const url = new URL(request.url, `http://${request.headers.host}`);
  const relativePath = url.pathname === "/" ? "/index.html" : url.pathname;
  const path = normalize(join(publicDir, relativePath));

  if (!path.startsWith(publicDir)) {
    text(response, 403, "Forbidden");
    return;
  }

  try {
    const body = await readFile(path);
    const ext = path.slice(path.lastIndexOf("."));
    response.writeHead(200, { "content-type": contentTypes[ext] || "application/octet-stream" });
    response.end(body);
  } catch {
    text(response, 404, "Not found");
  }
}

async function route(request, response) {
  const url = new URL(request.url, `http://${request.headers.host}`);

  try {
    if (request.method === "GET" && url.pathname === "/api/config") {
      json(response, 200, {
        dataDir,
        teller: {
          configured: tellerConfigured(),
          connectConfigured: tellerConnectConfigured(),
          applicationId: process.env.TELLER_APPLICATION_ID || null,
          environment: process.env.TELLER_ENVIRONMENT || "development",
          products: tellerProducts,
          apiBase: tellerBaseUrl,
        },
      });
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/accounts") {
      json(response, 200, await readJson("accounts.json", []));
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/transactions") {
      json(response, 200, await readJson("transactions.json", []));
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/enrollments") {
      json(response, 200, await readJson("enrollments.json", []));
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/enrollments") {
      json(response, 200, await saveEnrollment(await readBody(request)));
      return;
    }

    if (request.method === "POST" && url.pathname === "/api/import/teller") {
      json(response, 200, await importTeller());
      return;
    }

    if (request.method === "GET" && !url.pathname.startsWith("/api/")) {
      await serveStatic(request, response);
      return;
    }

    text(response, 404, "Not found");
  } catch (error) {
    json(response, 500, { error: error.message });
  }
}

await mkdir(dataDir, { recursive: true });
const { host, port } = splitAddr(addr);
createServer(route).listen(port, host, () => {
  console.log(`finance-prototype listening on http://${addr}`);
  console.log(`data directory: ${dataDir}`);
});
