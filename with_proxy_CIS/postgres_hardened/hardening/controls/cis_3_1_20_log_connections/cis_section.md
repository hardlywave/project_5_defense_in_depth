# 3.1.20 Ensure 'log_connections' is enabled (Automated)

## Profile Applicability:

* Level 1 - PostgreSQL

## Description

Enabling the `log_connections` setting causes each attempted connection to the server
to be logged, as well as successful completion of client authentication. This parameter
cannot be changed after the session start.

## Rationale

PostgreSQL does not maintain an internal record of attempted connections to the
database for later auditing. It is only by enabling the logging of these attempts that one
can determine if unexpected attempts are being made.

Note that enabling this without also enabling `log_disconnections` provides little value.
Generally, you would enable/disable the pair together.

## Audit

Execute the following SQL statement to verify the setting is enabled:

```
postgres=# show log_connections;
log_connections
-----------------
on
(1 row)
```

If not configured to `on`, this is a fail.

## Remediation

Execute the following SQL statement(s) to enable this setting:

```
postgres=# alter system set log_connections = 'on';
ALTER SYSTEM
postgres=# select pg_reload_conf();
pg_reload_conf
----------------
t
(1 row)
```

Then, in a new connection to the database, verify the change:

```
postgres=# show log_connections;
log_connections
-----------------
on
(1 row)
```

Note that you cannot verify this change in the same connection in which it was changed;
a new connection is needed.

## Default Value

`off`

## References

https://www.postgresql.org/docs/current/static/runtime-config-logging.html


