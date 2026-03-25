-- **Escenario:**
--
-- Eres el ingeniero de DualEntry. Tienes estas dos tablas:
--
-- ```sql
-- accounts
-- ---------
-- id          VARCHAR
-- name        VARCHAR
-- status      VARCHAR  -- 'active', 'inactive', 'suspended'
-- created_at  TIMESTAMP
--
-- transactions
-- -------------
-- id          VARCHAR
-- account_id  VARCHAR
-- amount      DECIMAL
-- type        VARCHAR  -- 'credit' o 'debit'
-- created_at  TIMESTAMP
-- ```
--
-- **Pregunta:**
--
-- Escríbeme un query que devuelva el **top 5 de cuentas activas** con el **mayor saldo actual**, mostrando:
-- - Nombre de la cuenta
-- - Total de créditos
-- - Total de débitos
-- - Saldo actual (créditos - débitos)
-- - Número de transacciones
--
-- Solo cuentas con status `'active'` y que tengan **al menos 1 transacción**.

WITH ranked AS (
    SELECT
        a.name,
        SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END) AS total_creditos,
        SUM(CASE WHEN t.type = 'debit' THEN t.amount ELSE 0 END) AS total_debitos,
        SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END) -
        SUM(CASE WHEN t.type = 'debit' THEN t.amount ELSE 0 END) AS saldo_actual,
        COUNT(t.id) AS total_transacciones,
        DENSE_RANK() OVER (
            ORDER BY (
                SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END) -
                SUM(CASE WHEN t.type = 'debit' THEN t.amount ELSE 0 END)
            ) DESC
        ) AS rk
    FROM accounts a
    JOIN transactions t ON t.account_id = a.id
    WHERE a.status = 'active'
    GROUP BY a.id, a.name
)
SELECT name, total_creditos, total_debitos, saldo_actual, total_transacciones
FROM ranked
WHERE rk <= 5;
