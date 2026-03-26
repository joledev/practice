```sql
-- Tienes estas tablas:
--
-- companies
-- ----------
-- id            VARCHAR
-- name          VARCHAR
-- industry      VARCHAR
-- created_at    TIMESTAMP
--
-- accounts
-- ---------
-- id            VARCHAR
-- company_id    VARCHAR
-- name          VARCHAR
-- balance       DECIMAL
-- created_at    TIMESTAMP
--
-- transactions
-- -------------
-- id            VARCHAR
-- account_id    VARCHAR
-- amount        DECIMAL
-- type          VARCHAR  -- 'credit', 'debit'
-- created_at    TIMESTAMP
```

-- **Pregunta:**
--
-- DualEntry quiere identificar empresas "en riesgo". Una empresa está en riesgo si **al menos una de sus cuentas tiene
-- saldo negativo** (balance < 0) **O** si el **volumen de débitos del último mes supera 2x el volumen de créditos del
-- último mes**.
--
-- Escríbeme un query que devuelva:
--
-- - Nombre de la empresa
-- - Industry
-- - Número de cuentas con saldo negativo
-- - Total de créditos del último mes
-- - Total de débitos del último mes
-- - Razón de riesgo: `'negative_balance'`, `'high_debits'`, o `'both'`
--
-- Ordenado por número de cuentas negativas descendente.


WITH
cuentas_en_riesgo AS (
    SELECT
        c.id,
        c.name,
        c.industry,
        COUNT(a.id) FILTER (WHERE a.balance < 0) AS cuentas_negativas
    FROM companies c
    INNER JOIN accounts a ON a.company_id = c.id
    GROUP BY c.id, c.name, c.industry
),
transacciones_ultimo_mes AS (
    SELECT
        c.id,
        SUM(t.amount) FILTER (WHERE t.type = 'credit') AS total_creditos,
        SUM(t.amount) FILTER (WHERE t.type = 'debit')  AS total_debitos
    FROM transactions t
    INNER JOIN accounts a ON t.account_id = a.id
    INNER JOIN companies c ON a.company_id = c.id
    WHERE t.created_at >= NOW() - INTERVAL '30 days'
    GROUP BY c.id
),
empresas_en_riesgo AS (
    SELECT
        cer.name,
        cer.industry,
        cer.cuentas_negativas,
        COALESCE(tem.total_creditos, 0) AS total_creditos,
        COALESCE(tem.total_debitos, 0)  AS total_debitos,
        CASE
            WHEN cer.cuentas_negativas > 0
             AND COALESCE(tem.total_debitos, 0) > COALESCE(tem.total_creditos, 0) * 2
                THEN 'both'
            WHEN cer.cuentas_negativas > 0
                THEN 'negative_balance'
            WHEN COALESCE(tem.total_debitos, 0) > COALESCE(tem.total_creditos, 0) * 2
                THEN 'high_debits'
        END AS risk_reason
    FROM cuentas_en_riesgo cer
    LEFT JOIN transacciones_ultimo_mes tem ON cer.id = tem.id
)
SELECT name, industry, cuentas_negativas, total_creditos, total_debitos, risk_reason
FROM empresas_en_riesgo
WHERE risk_reason IS NOT NULL
ORDER BY cuentas_negativas DESC;
