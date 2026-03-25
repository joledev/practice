```sql
-- Tienes estas tablas:
--
-- users
-- ------
-- id            VARCHAR
-- name          VARCHAR
-- email         VARCHAR
-- created_at    TIMESTAMP
--
-- invoices
-- ---------
-- id            VARCHAR
-- user_id       VARCHAR
-- amount        DECIMAL
-- status        VARCHAR  -- 'paid', 'pending', 'cancelled'
-- created_at    TIMESTAMP
--
-- payments
-- ---------
-- id            VARCHAR
-- invoice_id    VARCHAR
-- amount        DECIMAL
-- created_at    TIMESTAMP
```

-- **Pregunta:**
--
-- Escríbeme un query que devuelva **usuarios que tienen facturas pendientes sin pagar por más de 30 días**, mostrando:
--
-- - Nombre del usuario
-- - Email
-- - Número de facturas pendientes
-- - Monto total pendiente
-- - Fecha de la factura pendiente más antigua
--
-- Solo facturas con status `'pending'` cuya `created_at` sea hace más de 30 días. Ordenado por monto total pendiente descendente

WITH pendientes AS (
    SELECT
        u.name,
        u.email,
        COUNT(i.id) AS facturas_pendientes,
        SUM(i.amount) AS total_pendiente,
        MIN(i.created_at) AS antigua_pendiente
    FROM users u
    INNER JOIN invoices i ON i.user_id = u.id
    WHERE i.status = 'pending'
      AND i.created_at < NOW() - INTERVAL '30 days'
    GROUP BY u.id, u.name, u.email
)
SELECT name, email, facturas_pendientes, total_pendiente, antigua_pendiente
FROM pendientes
ORDER BY total_pendiente DESC;
