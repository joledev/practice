------------------------------
-- 1. JOINs — todos los tipos
------------------------------
-- INNER JOIN (solo coincidencias)
SELECT c.nombre, t.monto, t.fecha
FROM cuentas c
INNER JOIN transacciones t ON c.id = t.cuenta_id;

-- LEFT JOIN (todos de la izquierda, nulls si no hay match)
SELECT c.nombre, COUNT(t.id) AS num_transacciones
FROM cuentas c
LEFT JOIN transacciones t ON c.id = t.cuenta_id
GROUP BY c.nombre;

-- FULL OUTER JOIN (todos de ambos lados)
SELECT c.nombre, t.monto
FROM cuentas c
FULL OUTER JOIN transacciones t ON c.id = t.cuenta_id;

-- JOIN múltiple
SELECT u.nombre, c.numero, t.monto
FROM usuarios u
JOIN cuentas c ON u.id = c.usuario_id
JOIN transacciones t ON c.id = t.cuenta_id
WHERE t.fecha >= '2026-01-01';

-- SELF JOIN (comparar filas de la misma tabla)
SELECT a.id, a.monto, b.monto AS monto_anterior
FROM transacciones a
JOIN transacciones b ON a.cuenta_id = b.cuenta_id
    AND a.fecha > b.fecha;

---------------------
-- 2. CTEs completas
---------------------
-- CTE básica
WITH resumen AS (
    SELECT
        cuenta_id,
        SUM(monto) AS total,
        COUNT(*) AS num_transacciones
    FROM transacciones
    GROUP BY cuenta_id
)
SELECT * FROM resumen WHERE total > 10000;

-- CTEs múltiples encadenadas
WITH
activas AS (
    SELECT id, nombre FROM cuentas WHERE estado = 'activa'
),
saldos AS (
    SELECT
        cuenta_id,
        SUM(CASE WHEN tipo = 'credito' THEN monto ELSE -monto END) AS saldo
    FROM transacciones
    GROUP BY cuenta_id
),
resultado AS (
    SELECT a.nombre, s.saldo
    FROM activas a
    JOIN saldos s ON a.id = s.cuenta_id
)
SELECT * FROM resultado WHERE saldo < 0 ORDER BY saldo;

-- CTE recursiva (para jerarquías)
WITH RECURSIVE jerarquia AS (
    -- Base: nodo raíz
    SELECT id, nombre, parent_id, 0 AS nivel
    FROM categorias
    WHERE parent_id IS NULL

    UNION ALL

    -- Recursión: hijos
    SELECT c.id, c.nombre, c.parent_id, j.nivel + 1
    FROM categorias c
    JOIN jerarquia j ON c.parent_id = j.id
)
SELECT * FROM jerarquia ORDER BY nivel, nombre;

---------------------------------
-- 3. Window Functions completas
---------------------------------

-- ROW_NUMBER: numeración única por partición
SELECT
    cuenta_id,
    monto,
    fecha,
    ROW_NUMBER() OVER (PARTITION BY cuenta_id ORDER BY fecha DESC) AS rn
FROM transacciones;

-- RANK: permite empates, salta números
SELECT vendedor, ventas,
    RANK() OVER (ORDER BY ventas DESC) AS rank
FROM resumen;
-- Si hay empate en 2do: 1,2,2,4

-- DENSE_RANK: permite empates, NO salta números
SELECT vendedor, ventas,
    DENSE_RANK() OVER (ORDER BY ventas DESC) AS rank
FROM resumen;
-- Si hay empate en 2do: 1,2,2,3

-- SUM acumulado (running total)
SELECT
    fecha,
    monto,
    SUM(monto) OVER (
        PARTITION BY cuenta_id
        ORDER BY fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS saldo_acumulado
FROM transacciones;

-- AVG móvil (últimas 3 filas)
SELECT
    fecha,
    monto,
    AVG(monto) OVER (
        ORDER BY fecha
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS promedio_3_dias
FROM transacciones;

-- LAG: valor de la fila anterior
SELECT
    fecha,
    monto,
    LAG(monto, 1, 0) OVER (ORDER BY fecha) AS monto_anterior,
    monto - LAG(monto, 1, 0) OVER (ORDER BY fecha) AS diferencia
FROM transacciones;

-- LEAD: valor de la fila siguiente
SELECT
    fecha,
    monto,
    LEAD(monto) OVER (ORDER BY fecha) AS monto_siguiente
FROM transacciones;

-- FIRST_VALUE / LAST_VALUE
SELECT
    cuenta_id,
    fecha,
    monto,
    FIRST_VALUE(monto) OVER (
        PARTITION BY cuenta_id ORDER BY fecha
    ) AS primer_monto,
    LAST_VALUE(monto) OVER (
        PARTITION BY cuenta_id ORDER BY fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS ultimo_monto
FROM transacciones;

-- NTILE: dividir en N grupos (cuartiles, deciles)
SELECT
    cliente_id,
    total_compras,
    NTILE(4) OVER (ORDER BY total_compras) AS cuartil
FROM resumen_clientes;
-- cuartil 4 = top 25% de clientes

-----------------------------
-- 4. Agregaciones avanzadas
-----------------------------
-- CASE dentro de SUM (pivot manual)
SELECT
    cuenta_id,
    SUM(CASE WHEN tipo = 'credito' THEN monto ELSE 0 END) AS total_creditos,
    SUM(CASE WHEN tipo = 'debito' THEN monto ELSE 0 END) AS total_debitos,
    SUM(CASE WHEN tipo = 'credito' THEN monto ELSE -monto END) AS saldo
FROM transacciones
GROUP BY cuenta_id;

-- FILTER (PostgreSQL) — más limpio que CASE
SELECT
    cuenta_id,
    SUM(monto) FILTER (WHERE tipo = 'credito') AS creditos,
    SUM(monto) FILTER (WHERE tipo = 'debito') AS debitos
FROM transacciones
GROUP BY cuenta_id;

-- HAVING para filtrar grupos
SELECT
    cuenta_id,
    COUNT(*) AS num_transacciones,
    SUM(monto) AS total
FROM transacciones
GROUP BY cuenta_id
HAVING COUNT(*) > 10 AND SUM(monto) > 50000;

-- GROUPING SETS (múltiples niveles de agrupación)
SELECT
    cuenta_id,
    DATE_TRUNC('month', fecha) AS mes,
    SUM(monto) AS total
FROM transacciones
GROUP BY GROUPING SETS (
    (cuenta_id, DATE_TRUNC('month', fecha)),
    (cuenta_id),
    ()
);

--------------------------------
-- 5. Escenarios fintech reales
--------------------------------
-- Última transacción por cuenta
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cuenta_id ORDER BY fecha DESC) AS rn
    FROM transacciones
)
SELECT cuenta_id, monto, fecha, tipo
FROM ranked WHERE rn = 1;

-- Cuentas con saldo negativo
SELECT
    cuenta_id,
    SUM(CASE WHEN tipo = 'credito' THEN monto ELSE -monto END) AS saldo
FROM transacciones
GROUP BY cuenta_id
HAVING SUM(CASE WHEN tipo = 'credito' THEN monto ELSE -monto END) < 0;

-- Transacciones sospechosas: mismo monto, misma cuenta, mismo día
SELECT cuenta_id, monto, DATE(fecha) AS dia, COUNT(*) AS repeticiones
FROM transacciones
GROUP BY cuenta_id, monto, DATE(fecha)
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC;

-- Top 3 clientes por categoría
WITH ranked AS (
    SELECT
        categoria,
        cliente_id,
        SUM(monto) AS total,
        DENSE_RANK() OVER (PARTITION BY categoria ORDER BY SUM(monto) DESC) AS rk
    FROM transacciones t
    JOIN clientes c ON t.cuenta_id = c.id
    GROUP BY categoria, cliente_id
)
SELECT categoria, cliente_id, total
FROM ranked WHERE rk <= 3;

-- Variación mes a mes
WITH mensuales AS (
    SELECT
        DATE_TRUNC('month', fecha) AS mes,
        SUM(monto) AS total
    FROM transacciones
    GROUP BY DATE_TRUNC('month', fecha)
)
SELECT
    mes,
    total,
    LAG(total) OVER (ORDER BY mes) AS mes_anterior,
    ROUND(
        (total - LAG(total) OVER (ORDER BY mes)) /
        NULLIF(LAG(total) OVER (ORDER BY mes), 0) * 100,
        2
    ) AS variacion_pct
FROM mensuales ORDER BY mes;

-- Cuentas inactivas (sin transacciones en 30 días)
SELECT c.id, c.nombre, MAX(t.fecha) AS ultima_transaccion
FROM cuentas c
LEFT JOIN transacciones t ON c.id = t.cuenta_id
GROUP BY c.id, c.nombre
HAVING MAX(t.fecha) < NOW() - INTERVAL '30 days'
    OR MAX(t.fecha) IS NULL;

-- Percentil de gasto por cliente
SELECT
    cliente_id,
    total_gasto,
    PERCENT_RANK() OVER (ORDER BY total_gasto) AS percentil,
    NTILE(100) OVER (ORDER BY total_gasto) AS percentil_100
FROM (
    SELECT cliente_id, SUM(monto) AS total_gasto
    FROM transacciones
    GROUP BY cliente_id
) resumen;

----------------------------
-- 6. PostgreSQL específico
----------------------------
-- DATE_TRUNC
DATE_TRUNC('hour', timestamp_col)   -- trunca a la hora
DATE_TRUNC('day', timestamp_col)    -- trunca al día
DATE_TRUNC('month', timestamp_col)  -- trunca al mes
DATE_TRUNC('year', timestamp_col)   -- trunca al año

-- Intervalos
NOW() - INTERVAL '7 days'
NOW() - INTERVAL '1 month'
NOW() - INTERVAL '1 year'

-- EXTRACT
EXTRACT(YEAR FROM fecha)   -- año
EXTRACT(MONTH FROM fecha)  -- mes
EXTRACT(DOW FROM fecha)    -- día de semana (0=domingo)
EXTRACT(HOUR FROM fecha)   -- hora

-- COALESCE (null safety)
COALESCE(monto, 0)         -- si monto es null, usa 0
COALESCE(nombre, 'Sin nombre')

-- NULLIF (evitar división por cero)
monto / NULLIF(cantidad, 0)  -- si cantidad=0, retorna null

-- String functions
UPPER(nombre)
LOWER(email)
TRIM(texto)
LENGTH(texto)
SUBSTRING(texto FROM 1 FOR 3)
CONCAT(nombre, ' ', apellido)
texto || ' concatenado'    -- operador de concatenación

-- CAST
CAST(texto AS INTEGER)
texto::INTEGER             -- shorthand de PostgreSQL
fecha::DATE
numero::VARCHAR

-- JSONB
datos->'campo'             -- extrae como JSON
datos->>'campo'            -- extrae como texto
datos @> '{"key": "val"}' -- contiene

-------------------------------------------------------
-- 7. Índices — mencionarlos en entrevista impresiona
-------------------------------------------------------
-- Índice simple
CREATE INDEX idx_transacciones_cuenta ON transacciones(cuenta_id);

-- Índice compuesto (orden importa)
CREATE INDEX idx_trans_cuenta_fecha ON transacciones(cuenta_id, fecha DESC);

-- Índice parcial (solo para subconjunto de datos)
CREATE INDEX idx_trans_activas ON transacciones(cuenta_id)
WHERE estado = 'activa';

-- Índice para JSONB
CREATE INDEX idx_trans_metadata ON transacciones USING GIN(metadata);

-- Ver si un query usa índices
EXPLAIN ANALYZE
SELECT * FROM transacciones WHERE cuenta_id = 'ABC' AND fecha > '2026-01-01';
