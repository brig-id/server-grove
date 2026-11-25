// The person in the restore test (tests/restore/run.sh): an administrator
// with a passkey, before the database is lost and after it is restored.
//
//   node account.cjs create <setup link> <state file>
//   node account.cjs check <state file>
//
// `create` opens the setup link the new server printed, creates the first
// account with a passkey of Chromium's virtual authenticator, gets through
// the onboarding, and writes to <state file> what the server shows the
// account (its identities, the accounts of the administration) and the
// passkey itself, as the phone that holds it would keep it. `check` starts
// another browser with that passkey alone, signs in, and fails unless the
// server shows the same.
//
// Playwright is not a dependency of this repository: PLAYWRIGHT_MODULE names
// an installed `playwright` package. TEST_SPKI, when set, is the base64
// SHA-256 of the public key of the certificate the test's proxy serves.
"use strict";

const fs = require("node:fs");
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");

const RETRY_MS = 3500;

async function start() {
  const args = process.env.TEST_SPKI
    ? [`--ignore-certificate-errors-spki-list=${process.env.TEST_SPKI}`]
    : [];
  const browser = await chromium.launch({ args });
  const context = await browser.newContext();
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("WebAuthn.enable", { enableUI: false });
  const { authenticatorId } = await cdp.send("WebAuthn.addVirtualAuthenticator", {
    options: {
      protocol: "ctap2",
      transport: "internal",
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  });
  return { browser, page, cdp, authenticatorId };
}

// The passkey ceremonies are rate-limited: a press refused for going too
// fast is pressed again a little later, as a person would.
async function pressUntil(page, what, press, check, attempts = 6) {
  for (let i = 0; i < attempts; i++) {
    await press().catch(() => {});
    try {
      await check();
      return;
    } catch {
      await page.waitForTimeout(RETRY_MS);
    }
  }
  throw new Error(`${what}: did not happen after ${attempts} attempts (at ${page.url()})`);
}

/** `GET path` from the page, with its session: the parsed JSON. */
async function read(page, path) {
  for (let i = 0; i < 6; i++) {
    const response = await page.evaluate(async (p) => {
      const r = await fetch(p, { headers: { accept: "application/json" } });
      return { status: r.status, text: await r.text() };
    }, path);
    if (response.status === 200) return JSON.parse(response.text);
    if (response.status !== 429) {
      throw new Error(`GET ${path}: ${response.status} ${response.text}`);
    }
    await page.waitForTimeout(RETRY_MS);
  }
  throw new Error(`GET ${path}: still refused for going too fast`);
}

/** What the server shows the signed-in account, without what a sign-in
 * changes (the time of the last one). */
async function seen(page) {
  const byId = (a, b) => String(a.id).localeCompare(String(b.id));
  const identities = (await read(page, "/account/identities")).sort(byId);
  const accounts = (await read(page, "/admin/accounts"))
    .map(({ id, username, created_at, admin, suspended_at, passkeys, recovery_code }) => ({
      id,
      username,
      created_at,
      admin,
      suspended_at,
      passkeys,
      recovery_code,
    }))
    .sort(byId);
  return { identities, accounts };
}

async function create(setupLink, stateFile) {
  const { browser, page, cdp, authenticatorId } = await start();
  try {
    await page.goto(setupLink);
    await page.getByRole("heading", { name: "Set up this server" }).waitFor();
    await pressUntil(
      page,
      "the administrator's account",
      () => page.getByRole("button", { name: "Create the administrator’s account" }).click({ timeout: 2000 }),
      () => page.waitForURL(/\/welcome\/?/, { timeout: 5000 }),
    );

    // The onboarding: the recovery code, kept; then the identities.
    const code = page.getByRole("group", { name: "Your recovery code" }).locator("code");
    const shown = /^([A-Z2-7]{4}-){9}[A-Z2-7]{4}$/;
    for (let i = 0; i < 6; i++) {
      const text = await code.textContent({ timeout: 5000 }).catch(() => "");
      if (shown.test((text || "").trim())) break;
      const again = page.getByRole("button", { name: "Create a recovery code" });
      if (await again.isVisible()) await again.click();
      else await page.reload();
      await page.waitForTimeout(RETRY_MS);
    }
    await page.getByLabel("I kept my recovery code").check();
    await pressUntil(
      page,
      "the identities",
      () => page.getByRole("button", { name: "Continue to my identities" }).click({ timeout: 2000 }),
      () => page.waitForURL(/\/identities\/?$/, { timeout: 5000 }),
    );

    const state = await seen(page);
    if (state.identities.length === 0) throw new Error("the onboarding created no identity");
    if (state.accounts.length !== 1 || !state.accounts[0].admin) {
      throw new Error(`expected one administrator: ${JSON.stringify(state.accounts)}`);
    }
    const { credentials } = await cdp.send("WebAuthn.getCredentials", { authenticatorId });
    if (credentials.length !== 1) throw new Error(`${credentials.length} passkeys made`);
    fs.writeFileSync(stateFile, JSON.stringify({ origin: new URL(setupLink).origin, credentials, ...state }, null, 2), {
      mode: 0o600,
    });
    console.log(
      `✓ an administrator with a passkey and ${state.identities.length} identities: ${state.identities
        .map((i) => i.name)
        .join(", ")}`,
    );
  } finally {
    await browser.close();
  }
}

async function check(stateFile) {
  const before = JSON.parse(fs.readFileSync(stateFile, "utf8"));
  const { browser, page, cdp, authenticatorId } = await start();
  try {
    for (const credential of before.credentials) {
      await cdp.send("WebAuthn.addCredential", { authenticatorId, credential });
    }
    await page.goto(`${before.origin}/`);
    await pressUntil(
      page,
      "the sign-in with the passkey",
      () => page.getByRole("button", { name: "Use my passkey" }).click({ timeout: 2000 }),
      () => page.waitForURL(/\/identities\/?$/, { timeout: 5000 }),
    );
    const after = await seen(page);
    for (const part of ["identities", "accounts"]) {
      const was = JSON.stringify(before[part], null, 2);
      const is = JSON.stringify(after[part], null, 2);
      if (was !== is) throw new Error(`the ${part} changed.\nBefore: ${was}\nAfter: ${is}`);
    }
    console.log(
      `✓ the passkey signs in, and the server shows the same account and ${after.identities.length} identities`,
    );
  } finally {
    await browser.close();
  }
}

const [mode, ...rest] = process.argv.slice(2);
const run = mode === "create" ? create(rest[0], rest[1]) : mode === "check" ? check(rest[0]) : null;
if (!run) {
  console.error("usage: account.cjs create <setup link> <state file> | check <state file>");
  process.exit(2);
}
run.catch((e) => {
  console.error(`✗ ${e.message}`);
  process.exit(1);
});
