# server-grove

**grove** is the middle edition of the [brig·id](https://brig.id) server: for a community, an
association, a public server. One machine, looked after by a volunteer or a small team.

It is **not built yet**. It is planned for step 2 of v1
([`editions.md`](https://github.com/brig-id/spec/blob/main/editions.md)).

## What is decided

- **The same engine as seedling** ([`server-seedling`](https://github.com/brig-id/server-seedling)),
  and the same functions, administration included: one node, an embedded SQLite database.
  No PostgreSQL and no Redis: for one machine and a thousand accounts they would be two more
  services to run, back up and upgrade, for nothing.
- **What makes it grove**: it is delivered as a container image with a compose file, its
  data lives on its own volume and is **continuously replicated** to a second place, it
  exposes metrics, and its defaults suit a server open to others (quotas, abuse controls).
- It starts from today's deployment of the project's own server (image, compose file,
  reverse proxy).
- Moving from seedling to grove is an export and an import of the server's data; the
  server's domain cannot change in the move, because a passkey is bound to it.
- The same settings prefix as the other editions: `BRIGID_…`.

What an account, an identity, a passkey and a token are does not depend on the edition:
that lives in [`core`](https://github.com/brig-id/core) and
[`crypto`](https://github.com/brig-id/crypto).

## Licence

[AGPL-3.0-or-later](LICENSE), like the two other editions. There is no commercial licence.
