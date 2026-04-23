# Project 5 — Defense in Depth

A database security exploration project that applies the **defense-in-depth** principle to a PostgreSQL deployment. We start from a deliberately vulnerable baseline, carry out realistic attacks against it, and then incrementally layer defensive controls — configuration hardening, a proxy tier, and CIS-benchmark-based OS hardening — re-running the attacks at each stage to measure what each layer actually stops.

🔗 **Repository:** [github.com/hardlywave/project_5_defense_in_depth](https://github.com/hardlywave/project_5_defense_in_depth)
🍴 **Upstream:** forked from [duetocode/project_5_defense_in_depth](https://github.com/duetocode/project_5_defense_in_depth)

---

## 🎯 Objectives

- Build a realistic PostgreSQL threat model using the **STRIDE** methodology (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege).
- Reproduce concrete attacks end-to-end in an isolated Docker lab.
- Design and implement successive layers of defensive controls.
- Verify empirically which threats each layer mitigates and which remain.
- Document the full workflow — threat model, attacks, controls, residual risk — for reproducibility.

---

## 🧠 Methodology — STRIDE + Defense in Depth

We decomposed the PostgreSQL deployment into its data flows, trust boundaries, and assets, then enumerated threats against each element using STRIDE. The resulting threat model is visualized as an SVG data-flow diagram in `doc/` with threats mapped onto the corresponding trust boundaries.

From the threat list we derived a **layered defense strategy**, reflected directly in the repository structure:

```
vulnerable baseline ──► hardened config ──► + proxy tier ──► + CIS-benchmark hardening
```

Each subsequent layer assumes the previous one is in place, so the project can also be read as a case study in how the attack surface shrinks as controls compound.

---

## 📂 Repository Structure

```
project_5_defense_in_depth/
├── demo/               # Dockerized attack lab — baseline vulnerable system + attacker container
├── doc/                # Threat model, STRIDE analysis, SVG data-flow / threat diagrams
├── hardened-system/    # Layer 1: PostgreSQL with hardened configuration (auth, TLS, roles, logging)
├── with_proxy/         # Layer 2: adds a proxy/gateway in front of the database
└── with_proxy_CIS/     # Layer 3: proxy + CIS Benchmark hardening applied to the host/OS
```

| Folder | Role | What's inside |
|---|---|---|
| `demo/` | **Attack playground** | `docker-compose` setup with a `postgres` service and a separate `client_attacker` container on a shared Docker bridge network. Shell scripts reproduce each attack scenario. |
| `doc/` | **Threat model & analysis** | STRIDE breakdown of the PostgreSQL deployment, data-flow diagram in SVG, per-threat descriptions and proposed mitigations. |
| `hardened-system/` | **Defense layer 1** | Dockerfiles and scripts that apply PostgreSQL-level hardening (stronger authentication, TLS in transit, least-privilege roles, audit logging, etc.). |
| `with_proxy/` | **Defense layer 2** | Adds a proxy/gateway component so clients no longer speak directly to the database — giving us a controllable choke point for auth and traffic policy. |
| `with_proxy_CIS/` | **Defense layer 3** | Same proxy topology plus hardening aligned with the **CIS Benchmarks** (host / OS-level controls applied on top of the application controls). |

---

## 💥 Attack Demonstrations

The `demo/` lab spins up two containers on an isolated Docker network:

| Container | IP | Role |
|---|---|---|
| `postgres` | `172.20.0.10` | Target database (default / vulnerable config) |
| `client_attacker` | `172.20.0.20` | Tooling container used to run attacks against the target |

Implemented attack scenarios include:

- **Credentials in cleartext on the wire.** A packet capture with `tcpdump` on the attacker container demonstrates that, without TLS, PostgreSQL authentication traffic exposes credentials to anyone sharing the network segment. This is a textbook STRIDE **Information Disclosure** case against the client-to-DB trust boundary.
- **Password dictionary attack.** Brute-force / dictionary-based login attempts against the database service, exercising the **Spoofing** and **Elevation of Privilege** threat categories and motivating auth-hardening and rate-limiting controls downstream.

Each attack is first executed against the vulnerable baseline, then re-executed against the hardened / proxied / CIS-hardened stacks to observe which defense actually neutralizes it.

---

## 🛡️ Defense Layers

### Layer 1 — Hardened PostgreSQL (`hardened-system/`)
Application-level controls on the database itself: stricter `pg_hba.conf` rules, TLS-only connections, scoped roles and privileges, tightened default settings, and log/audit configuration. This is the first and cheapest line of defense, and it already kills several STRIDE threats (notably plaintext sniffing).

### Layer 2 — Proxy tier (`with_proxy/`)
The database is moved behind a proxy/gateway. Clients connect to the proxy; the proxy connects to PostgreSQL. This introduces a clean policy enforcement point — we can authenticate, rate-limit, and log at the edge without trusting every client, and we remove direct network reachability to the database itself.

### Layer 3 — Proxy + CIS Benchmark hardening (`with_proxy_CIS/`)
On top of the proxied architecture, we apply host-level hardening based on the **CIS Benchmarks**: filesystem permissions, kernel/networking parameters, service minimization, and related controls. This addresses the threat classes that the application layer alone can't cover (local privilege escalation, container escape surface, unnecessary exposed services, etc.) and rounds out the defense-in-depth picture.

---

## 🚀 Running Locally

> ⚠️ For educational use only. The attack scripts intentionally target a lab environment and must not be pointed at any system you don't own.

**Prerequisites:** Docker and Docker Compose.

To spin up a given layer, `cd` into the corresponding folder and start the stack:

```bash
# Vulnerable baseline + attacker
cd demo
docker compose up --build

# Layer 1 — hardened PostgreSQL
cd hardened-system
docker compose up --build

# Layer 2 — with proxy
cd with_proxy
docker compose up --build

# Layer 3 — with proxy + CIS hardening
cd with_proxy_CIS
docker compose up --build
```

Each folder contains its own shell scripts for launching the corresponding attack or verification steps. See the per-folder README / notes for exact commands.

---

## 🛠 Technologies

- **PostgreSQL** — target database
- **Docker** / **Docker Compose** — reproducible isolated lab environment
- **Bash** shell scripts — attack and setup automation
- **tcpdump** — packet capture for the sniffing demo
- **STRIDE** — threat modeling methodology
- **CIS Benchmarks** — OS/host hardening reference

Languages: **Shell** (~71%), **Dockerfile** (~29%).

---

## 📚 Documentation

Full threat modeling documentation, including the STRIDE breakdown and the SVG data-flow / threat diagram, lives in [`doc/`](./doc). Read that first — it gives the context for why each defense layer looks the way it does.

---

## 👥 Team

Team project for a database security course. Contributions across threat modeling, attack scripting, defensive configuration, and documentation.

Maintainer of this fork: **[@hardlywave](https://github.com/hardlywave)**

---

## ⚠️ Disclaimer

This repository is strictly for academic and educational purposes. The attack demonstrations are designed to run inside the isolated Docker network provided in this repo. Do not use any part of this project against systems you do not own or do not have explicit written permission to test.
