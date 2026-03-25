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



