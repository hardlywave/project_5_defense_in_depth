# Database Hardening Report

## 1. Program Description

This project demonstrates database security hardening techniques applied to a PostgreSQL 16 deployment running in Docker Compose. The objective is to transform an insecure baseline system into a defense-in-depth architecture using a connection proxy, transport encryption, mutual authentication, and least-privilege access control.

### Baseline System

The baseline system (`../baseline/docker-compose.yaml`) consists of two containers:

- **database** (postgres:16) -- PostgreSQL with port 5432 exposed directly to the host, using a superuser account (`postgres`) with a plaintext password.
- **client** (debian:trixie) -- A general-purpose client container.

The database stores sensitive data including employee names, credit card numbers, and salary information (`../baseline/init.sql`).

### Threat Model

The baseline system is vulnerable to the following threats:

| Threat | Description |
|--------|-------------|
| Eavesdropping | All traffic between client and database is unencrypted. An attacker on the network can capture credentials and query results in plaintext. |
| Unauthorized access | Any network host can connect directly to PostgreSQL on port 5432 with only a password. |
| Privilege escalation | The only available account is the `postgres` superuser, which has unrestricted access to all data and database configuration. |
| No client identity verification | The database has no way to verify the identity of connecting clients beyond a shared password. |

## 2. Solution Architecture

The hardened system (`docker-compose.yaml`) introduces four independent security layers.

### Architecture Diagram

```mermaid
graph LR
    subgraph frontend["frontend network"]
    client["client\n(postgres:16)"]
        pgbouncer["database\n(PgBouncer)\nport 5432"]
    end
    subgraph backend["backend network"]
        pgbouncer
        postgres["postgres\n(PostgreSQL 16)\nnot exposed"]
    end
    client -- "mTLS\n(cert only)" --> pgbouncer
    pgbouncer -- "mTLS\n(cert only)" --> postgres
```

- The **client** container exists only on the `frontend` network.
- The **database** service (PgBouncer) bridges both `frontend` and `backend` networks.
- The **postgres** service exists only on the `backend` network and exposes no ports to the host.

### Layer 1 -- Network Isolation

Two Docker networks (`backend` and `frontend`) segment the infrastructure. The client container can only resolve and reach the `database` service (PgBouncer). The `postgres` service is invisible to the client -- DNS resolution fails and TCP connections are impossible.

### Layer 2 -- TLS Everywhere

All database traffic is encrypted in transit:

- **Client to PgBouncer** (frontend TLS): PgBouncer presents a server certificate (CN=`database`) and requires TLS from all connecting clients. Plaintext connections are rejected with `FATAL: SSL required`.
- **PgBouncer to PostgreSQL** (backend TLS): PgBouncer connects to PostgreSQL over TLS (`server_tls_sslmode=verify-full`), verifies the PostgreSQL server certificate against the CA chain, and presents its own client certificate to PostgreSQL.
- **PostgreSQL server TLS**: PostgreSQL is configured with `ssl=on` and presents a server certificate (CN=`postgres`) signed by the intermediate CA.

### Layer 3 -- Mutual TLS (mTLS)

PgBouncer is configured with `client_tls_sslmode=verify-full`, which requires clients to present a valid certificate signed by the trusted CA chain. PostgreSQL is configured with `clientcert=verify-full` and `cert` authentication for the PgBouncer backend role. The result is mutual TLS on both hops with no password fallback.

### Layer 4 -- Authentication and Authorization

Authentication and authorization are separated:

- **Authentication** is certificate-based on both hops:
  1. The frontend client authenticates to PgBouncer with certificate subject `CN=finance`.
  2. PgBouncer authenticates to PostgreSQL with certificate subject `CN=database`.
- **Authorization** is enforced by PostgreSQL roles. PgBouncer uses the least-privilege backend role `database` (`init.sql`), which can only execute SELECT queries on the `secret_data` table. INSERT, UPDATE, and DELETE operations are denied by the database.
- **Identity mapping note**: the client connects to PgBouncer as `finance`, but PgBouncer uses a fixed backend PostgreSQL role `database`, so `current_user` and `session_user` inside PostgreSQL resolve to `database`.

### PKI Structure

The certificate infrastructure uses a two-tier hierarchy:

```mermaid
graph TD
    root["CS590-ROOT\n(Root CA)"]
    intermediate["CS590-INTERMEDIATE\n(Intermediate CA)"]
  cert_db["Serial 1006: CN=database\n(server + client cert, PgBouncer)"]
  cert_pg["Serial 1005: CN=postgres\n(server cert, PostgreSQL)"]
    cert_cl["Serial 1007: CN=finance\n(client cert, clientAuth)"]
    root --> intermediate
    intermediate --> cert_db
    intermediate --> cert_pg
    intermediate --> cert_cl
```

All certificates are signed by the intermediate CA and verified against the full chain (`certs/ca-chain.cert.pem`). The CA and intermediate CA directories are maintained in `../keywork/root_ca/` and `../keywork/intermediate_ca/` respectively.

### Key Files

| File | Purpose |
|------|---------|
| `certs/ca-chain.cert.pem` | CA trust chain (intermediate + root), used by all services for certificate verification |
| `certs/server.crt` / `server.key` | PostgreSQL server certificate and private key (CN=postgres) |
| `certs/pgbouncer.crt` / `pgbouncer.key` | PgBouncer certificate and private key (CN=database, used for both frontend server auth and backend client auth) |
| `certs/client.crt` / `client.key` | Client certificate and private key (CN=finance, extendedKeyUsage=clientAuth) |

### Connecting to the Database

From within the client container, connect to the database through PgBouncer as the `finance` user:

```bash
psql "host=database port=5432 dbname=mydb user=finance \
  sslmode=verify-full sslcert=/certs/client.crt sslkey=/certs/client.key sslrootcert=/certs/ca.crt"
```

PgBouncer authenticates that frontend certificate and then opens the PostgreSQL session as backend role `database`, so PostgreSQL-side role checks apply to `database` rather than `finance`.

## 3. Audit Results

The following tests were executed against the running `with_proxy` stack to verify each security layer.

| # | Test | Result | Evidence |
|---|------|--------|----------|
| 1 | PostgreSQL port not exposed to host | **PASS** | `docker compose port postgres 5432` returns `:0` (no binding); PgBouncer returns `0.0.0.0:5432` |
| 2 | SSL enabled on PostgreSQL | **PASS** | `SHOW ssl` returns `on` |
| 3 | Client with cert connects without password | **PASS** | `psql` with `sslmode=verify-full sslcert=/certs/client.crt sslkey=/certs/client.key` as `finance` succeeds without a password; PostgreSQL reports `current_user = database` |
| 4 | Client without cert is rejected | **PASS** | `psql` without cert files: `SSL error: tlsv13 alert certificate required` |
| 5 | Client without cert is rejected even over trusted TLS | **PASS** | `psql` with `sslrootcert` but without `sslcert`/`sslkey`: `SSL error: tlsv13 alert certificate required` |
| 6 | Backend connection uses certificate-authenticated SSL | **PASS** | `pg_stat_ssl JOIN pg_stat_activity` shows `ssl = t` and a non-null `client_dn` for PgBouncer's `database` session |
| 7 | Backend role cannot INSERT | **PASS** | `INSERT INTO secret_data VALUES (...)` through PgBouncer returns `ERROR: permission denied for table secret_data`, confirming the effective backend role `database` remains read-only |
| 8 | Client cannot reach PostgreSQL directly | **PASS** | `echo > /dev/tcp/postgres/5432` from client: `postgres: Name or service not known` |

### Audit Interpretation

- **Tests 1 and 8** confirm **network isolation**: PostgreSQL is unreachable from both the host and the client container.
- **Tests 2 and 6** confirm **TLS everywhere**: PostgreSQL has SSL enabled, and the backend connection from PgBouncer uses certificate-authenticated TLS.
- **Tests 3, 4, and 5** confirm **passwordless mTLS**: a valid client certificate is required to establish a connection, and no password is needed.
- **Test 7** confirms **least-privilege authorization**: the backend role can read data but cannot modify it.

## 4. Baseline vs. Hardened Comparison

| Aspect | Baseline | Hardened |
|--------|----------|---------|
| Database exposure | Port 5432 exposed to host | Not exposed; only reachable via PgBouncer on the backend network |
| Connection proxy | None | PgBouncer acts as a transparent proxy (service name `database`) |
| Encryption | None | TLS on all connections (client-to-proxy and proxy-to-database) |
| Client identity | None | mTLS -- clients must present a CA-signed certificate |
| Authentication | Superuser password only | Certificate-only auth on both hops |
| Authorization | Superuser (`postgres`) with full access | Least-privilege backend role (`database`) with SELECT-only grant |
| Network segmentation | Single default network | Separate `frontend` and `backend` networks |
