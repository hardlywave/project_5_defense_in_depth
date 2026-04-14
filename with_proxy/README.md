# PostgreSQL Security Demo

## Prerequisite

A docker engine installation, such as `Docker Desktop` or `OrbStack`.

## How to start the project

1. Enter the `with_proxy` directory
2. Run `docker compose up -d`

## Access the database with the legit client

You can access the database via the `client` container:

1. Access the bash shell of the container: `docker exec -it client bash`
2. Connect to the database: `psql "host=database port=5432 dbname=mydb user=finance sslmode=verify-full sslcert=/certs/client.crt sslkey=/certs/client.key sslrootcert=/certs/ca.crt"`

---

## Rules for the attacker

### Setup

1. You will be provided with a `docker-compose.yml` file inside the `with_proxy` directory. Run it to start the environment — it will spin up a client, a proxy, and a database container, each already configured with certificates.
2. To simulate a legitimate user, enter the client container, connect to the database, and interact with it as an approved user.

### Attacker rules

3. You are not allowed to use any Docker commands (`docker exec`, `docker inspect`, `docker logs`, etc.). Everything must be discovered manually.
4. You must work from your laptop's terminal only - no access to the container shell directly.
5. You start with zero knowledge. You do not know any IP addresses, usernames, passwords, port numbers, or service names. Everything must be discovered by yourself.
6. You have access to the `frontend` network only — the same network as the client. The database and other infrastructure servers are deployed inside an isolated `backend` network, which is not accessible to you directly. This simulates a real-world production setup where databases are kept in a separate isolated network (such as a private VPC in AWS or similar cloud services).
7. You are not allowed to modify the `docker-compose.yml` file or any configuration files.
8. You are not allowed to stop or restart any containers.

### Goal

9. Your goal is to gain access to the database and retrieve the data from it by any means available within these rules.

### Hint

10. Start by discovering what is on the network.
