CREATE TABLE secret_data (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50),
  credit_card VARCHAR(20),
  salary INTEGER
);

INSERT INTO secret_data VALUES
  (1, 'alice',   '4111-1111-1111-1111', 95000),
  (2, 'bob',     '5500-0000-0000-0004', 87000),
  (3, 'charlie', '3782-8224-6310-005',  110000);

-- PgBouncer authenticates frontend clients by certificate CN=finance and
-- connects upstream as backend role CN=database using certificate auth only.
CREATE ROLE database LOGIN;
GRANT SELECT ON secret_data TO database;