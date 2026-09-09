async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { "content-type": "application/json" },
    ...options,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(body || response.statusText);
  }

  return response.json();
}

function money(value) {
  const amount = Number.parseFloat(value || "0");
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount);
}

function byDateDesc(a, b) {
  return String(b.date || "").localeCompare(String(a.date || ""));
}

function txAmountClass(tx) {
  const amount = Number.parseFloat(tx.amount || "0");
  return amount < 0 ? "negative" : "positive";
}

function maskToken(token) {
  if (!token) return "no token";
  return `${token.slice(0, 8)}...${token.slice(-4)}`;
}

function summarize(accounts, transactions) {
  const today = new Date();
  const thirtyDaysAgo = new Date(today);
  thirtyDaysAgo.setDate(today.getDate() - 30);

  let spending = 0;
  let income = 0;

  for (const tx of transactions) {
    const date = new Date(`${tx.date}T00:00:00`);
    if (date < thirtyDaysAgo) continue;

    const amount = Number.parseFloat(tx.amount || "0");
    if (amount < 0) spending += Math.abs(amount);
    if (amount > 0) income += amount;
  }

  return { accounts: accounts.length, transactions: transactions.length, spending, income };
}

function renderEnrollments(enrollments) {
  const container = document.querySelector("[data-enrollments]");
  container.innerHTML = "";

  if (enrollments.length === 0) {
    container.innerHTML = `<p class="empty">No Teller enrollments yet.</p>`;
    return;
  }

  for (const enrollment of enrollments) {
    const el = document.createElement("article");
    el.className = "enrollment";
    el.innerHTML = `
      <div>
        <h3>${enrollment.institutionName || "Unknown institution"}</h3>
        <p>${enrollment.enrollmentId || "unknown enrollment"} - ${maskToken(enrollment.accessToken)}</p>
      </div>
      <span>${enrollment.environment || "unknown"}</span>
    `;
    container.appendChild(el);
  }
}

function renderAccounts(accounts) {
  const container = document.querySelector("[data-accounts]");
  container.innerHTML = "";

  if (accounts.length === 0) {
    container.innerHTML = `<p class="empty">No accounts imported yet.</p>`;
    return;
  }

  for (const account of accounts) {
    const el = document.createElement("article");
    el.className = "account";
    el.innerHTML = `
      <div>
        <h3>${account.name || "Unnamed account"}</h3>
        <p>${account.institution?.name || "Unknown institution"} - ${account.subtype || account.type || "account"} - ${account.last_four || "----"}</p>
      </div>
      <span>${account.status || "unknown"}</span>
    `;
    container.appendChild(el);
  }
}

function renderTransactions(transactions) {
  const tbody = document.querySelector("[data-transactions]");
  tbody.innerHTML = "";

  if (transactions.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" class="empty">No transactions imported yet.</td></tr>`;
    return;
  }

  for (const tx of transactions.slice().sort(byDateDesc).slice(0, 100)) {
    const row = document.createElement("tr");
    const category = tx.details?.category || "uncategorized";
    const name = tx.details?.counterparty?.name || tx.description || "Unknown";
    row.innerHTML = `
      <td>${tx.date || ""}</td>
      <td>
        <strong>${name}</strong>
        <span>${tx.description || ""}</span>
      </td>
      <td>${category}</td>
      <td>${tx.status || ""}</td>
      <td class="${txAmountClass(tx)}">${money(tx.amount)}</td>
    `;
    tbody.appendChild(row);
  }
}

function renderSummary(summary, config) {
  document.querySelector("[data-account-count]").textContent = summary.accounts;
  document.querySelector("[data-transaction-count]").textContent = summary.transactions;
  document.querySelector("[data-spending]").textContent = money(summary.spending);
  document.querySelector("[data-income]").textContent = money(summary.income);
  document.querySelector("[data-teller-status]").textContent = config.teller.configured
    ? "Teller configured"
    : "Teller not configured";

  const connectButton = document.querySelector("[data-connect]");
  connectButton.disabled = !config.teller.connectConfigured;
  connectButton.title = config.teller.connectConfigured
    ? "Connect a Teller enrollment"
    : "Set TELLER_APPLICATION_ID to enable Teller Connect";
}

async function refresh() {
  const [config, accounts, transactions, enrollments] = await Promise.all([
    request("/api/config"),
    request("/api/accounts"),
    request("/api/transactions"),
    request("/api/enrollments"),
  ]);

  renderSummary(summarize(accounts, transactions), config);
  renderEnrollments(enrollments);
  renderAccounts(accounts);
  renderTransactions(transactions);
  return config;
}

async function saveEnrollment(enrollment, config) {
  const result = await request("/api/enrollments", {
    method: "POST",
    body: JSON.stringify({
      accessToken: enrollment.accessToken,
      userId: enrollment.user?.id,
      enrollmentId: enrollment.enrollment?.id,
      institutionName: enrollment.enrollment?.institution?.name,
      environment: config.teller.environment,
      raw: enrollment,
    }),
  });

  document.querySelector("[data-import-status]").textContent =
    `Saved enrollment for ${result.institutionName || "institution"}.`;
  await refresh();
}

async function connectTeller(config) {
  const status = document.querySelector("[data-import-status]");

  if (!config.teller.connectConfigured) {
    status.textContent = "Set TELLER_APPLICATION_ID before connecting.";
    return;
  }

  if (!window.TellerConnect) {
    status.textContent = "Teller Connect did not load.";
    return;
  }

  const tellerConnect = window.TellerConnect.setup({
    applicationId: config.teller.applicationId,
    environment: config.teller.environment,
    products: config.teller.products,
    onSuccess: (enrollment) => {
      saveEnrollment(enrollment, config).catch((error) => {
        status.textContent = error.message;
      });
    },
    onExit: () => {
      status.textContent = "Teller Connect closed.";
    },
  });

  tellerConnect.open();
}

async function importTeller() {
  const button = document.querySelector("[data-import]");
  const status = document.querySelector("[data-import-status]");
  button.disabled = true;
  status.textContent = "Importing...";

  try {
    const result = await request("/api/import/teller", { method: "POST" });
    status.textContent = `Imported ${result.accounts} accounts and ${result.transactions} transactions.`;
    await refresh();
  } catch (error) {
    status.textContent = error.message;
  } finally {
    button.disabled = false;
  }
}

let appConfig = null;

document.querySelector("[data-import]").addEventListener("click", importTeller);
document.querySelector("[data-connect]").addEventListener("click", () => {
  connectTeller(appConfig).catch((error) => {
    document.querySelector("[data-import-status]").textContent = error.message;
  });
});

refresh().then((config) => {
  appConfig = config;
}).catch((error) => {
  document.querySelector("[data-import-status]").textContent = error.message;
});
