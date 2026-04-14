# 4.5 Ensure excessive function privileges are revoked (Automated)

## Profile Applicability

* Level 1 - PostgreSQL

## Description

In certain situations, to provide the required functionality, PostgreSQL needs to execute
internal logic (stored procedures, functions, triggers, etc.) and/or external code modules
with elevated privileges. However, if the privileges required for execution are at a higher
level than the privileges assigned to organizational users invoking the functionality
applications/programs, those users are indirectly provided with greater privileges than
assigned by their organization. This is known as privilege elevation. Privilege elevation
must be utilized only where necessary. Execute privileges for application functions
should be restricted to authorized users only.

## Rationale

Ideally, all application source code should be vetted to validate interactions between the
application and the logic in the database, but this is usually not possible or feasible with
available resources even if the source code is available. The DBA should attempt to
obtain assurances from the development organization that this issue has been
addressed and should document what has been discovered. The DBA should also
inspect all application logic stored in the database (in the form of functions, rules, and
triggers) for excessive privileges.

## Audit

Functions in PostgreSQL can be created with the `SECURITY DEFINER` option. When
`SECURITY DEFINER` functions are executed by a user, said function is run with the
privileges of the user who created it, not the user who is running it.
To list all functions that have `SECURITY DEFINER`, run the following SQL:

```
# whoami
root
# sudo -iu postgres
# psql -c "SELECT nspname, proname, proargtypes, prosecdef, rolname,
proconfig FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid JOIN
pg_authid a ON a.oid = p.proowner WHERE proname NOT LIKE 'pgaudit%' AND
(prosecdef OR NOT proconfig IS NULL);"
```

In the query results, a `prosecdef` value of '`t`' on a row indicates that that function uses
privilege elevation.

If elevation privileges are utilized which are not required or are expressly forbidden by
organizational guidance, this is a fail.

## Remediation

Where possible, revoke SECURITY DEFINER on PostgreSQL functions. To change a
SECURITY DEFINER function to SECURITY INVOKER, run the following SQL:

```
# whoami
root
# sudo -iu postgres
# psql -c "ALTER FUNCTION [functionname] SECURITY INVOKER;"
```

If it is not possible to revoke SECURITY DEFINER, ensure the function can be executed
by only the accounts that absolutely need such functionality:

```
postgres=# SELECT proname, proacl FROM pg_proc WHERE proname =
'delete_customer';
proname | proacl
-----------------+--------------------------------------------------------
delete_customer  | {=X/postgres,postgres=X/postgres,appreader=X/postgres}
(1 row)
postgres=# REVOKE EXECUTE ON FUNCTION delete_customer(integer,boolean) FROM
appreader;
REVOKE
postgres=# SELECT proname, proacl FROM pg_proc WHERE proname =
'delete_customer';
proname | proacl
-----------------+--------------------------------------------------------
delete_customer  | {=X/postgres,postgres=X/postgres}
(1 row)
```
Based on the output above, appreader=X/postgres no longer exists in the proacl
column results returned from the query and confirms appreader is no longer granted
execute privilege on the function.

## References

1. https://www.postgresql.org/docs/current/static/catalog-pg-proc.html
2. https://www.postgresql.org/docs/current/static/sql-grant.html
3. https://www.postgresql.org/docs/current/static/sql-revoke.html
4. https://www.postgresql.org/docs/current/static/sql-createfunction.html