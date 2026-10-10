/* STOCK MARKET ANALYSIS IN SQL — SQL SERVER EDITION
Project: six NSE stocks, Jan 2015–Jul 2018.
*/

use Stock_Market
-- TASK 1: Trading history in Bajaj Auto
SELECT COUNT(*) AS trading_days, MIN([date]) AS first_day, MAX([date]) AS last_day
FROM [Bajaj Auto];

-- TASK 2: Eicher Motors' five highest closes
SELECT TOP (5) [date], close_price
FROM dbo.[Eicher Motors]
ORDER BY close_price DESC;

-- TASK 3: TCS average closing price by year
SELECT YEAR([date]) AS [year],
       ROUND(AVG(CAST(close_price AS DECIMAL(18,4))), 2) AS avg_close
FROM dbo.TCS
GROUP BY YEAR([date])
ORDER BY [year];

-- TASK 4: Find rows with missing deliverable quantity across all six stocks
SELECT 'bajaj_auto' AS stock, [date] FROM dbo.[Bajaj Auto] WHERE Deliverable_Quantity IS NULL
UNION ALL
SELECT 'eicher_motors', [date] FROM dbo.[Eicher Motors] WHERE Deliverable_Quantity IS NULL
UNION ALL
SELECT 'hero_motocorp', [date] FROM dbo.Hero_Motocorp WHERE Deliverable_Quantity IS NULL
UNION ALL
SELECT 'infosys', [date] FROM dbo.Infosys WHERE Deliverable_Quantity IS NULL
UNION ALL
SELECT 'tcs', [date] FROM dbo.tcs WHERE Deliverable_Quantity IS NULL
UNION ALL
SELECT 'tvs_motors', [date] FROM dbo.tvs_motors WHERE Deliverable_Quantity IS NULL
ORDER BY stock, [date];

-- TASK 5: Bajaj Auto 20-day and 50-day moving averages
DROP TABLE IF EXISTS dbo.bajaj1;
WITH numbered AS (
    SELECT [date], close_price,
           ROW_NUMBER() OVER (ORDER BY [date]) AS rn,
           AVG(CAST(close_price AS DECIMAL(18,4))) OVER (
               ORDER BY [date] ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
           ) AS raw_ma20,
           AVG(CAST(close_price AS DECIMAL(18,4))) OVER (
               ORDER BY [date] ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
           ) AS raw_ma50
    FROM dbo.[Bajaj Auto]
)
SELECT [date], close_price,
       CASE WHEN rn >= 20 THEN ROUND(raw_ma20, 2) END AS ma20,
       CASE WHEN rn >= 50 THEN ROUND(raw_ma50, 2) END AS ma50
INTO dbo.bajaj1
FROM numbered;

SELECT * FROM dbo.bajaj1 ORDER BY [date];

-- TASK 6: Master table with closing prices for all six stocks
DROP TABLE IF EXISTS dbo.master_table;
SELECT b.[date],
       b.close_price AS bajaj,
       t.close_price AS tcs,
       tv.close_price AS tvs,
       i.close_price AS infosys,
       e.close_price AS eicher,
       h.close_price AS hero
INTO dbo.master_table
FROM dbo.[Bajaj Auto] b
JOIN dbo.tcs t ON t.[date] = b.[date]
JOIN dbo.tvs_motors tv ON tv.[date] = b.[date]
JOIN dbo.infosys i ON i.[date] = b.[date]
JOIN dbo.[Eicher Motors] e ON e.[date] = b.[date]
JOIN dbo.hero_motocorp h ON h.[date] = b.[date];

SELECT * FROM dbo.master_table ORDER BY [date];

-- TASK 7: Golden-cross Buy/Sell/Hold signals for Bajaj Auto
DROP TABLE IF EXISTS dbo.bajaj2;
WITH lagged AS (
    SELECT [date], close_price, ma20, ma50,
           LAG(ma20) OVER (ORDER BY [date]) AS prev_ma20,
           LAG(ma50) OVER (ORDER BY [date]) AS prev_ma50
    FROM dbo.bajaj1
)
SELECT [date], close_price,
       CASE
           WHEN ma20 IS NULL OR ma50 IS NULL
             OR prev_ma20 IS NULL OR prev_ma50 IS NULL THEN 'Hold'
           WHEN ma20 > ma50 AND prev_ma20 <= prev_ma50 THEN 'Buy'
           WHEN ma20 < ma50 AND prev_ma20 >= prev_ma50 THEN 'Sell'
           ELSE 'Hold'
       END AS [signal]
INTO dbo.bajaj2
FROM lagged;

SELECT * FROM dbo.bajaj2 ORDER BY [date];

-- TASK 8: Count Bajaj Auto signals
SELECT [signal], COUNT(*) AS days
FROM dbo.bajaj2
GROUP BY [signal]
ORDER BY [signal];

-- TASK 9: Signal on a specific date
SELECT [signal]
FROM dbo.bajaj2
WHERE [date] = '2018-06-21';

-- TASK 10: Signal summary for all six stocks
DROP TABLE IF EXISTS dbo.all_stock_signals;
WITH prices AS (
    SELECT 'Bajaj Auto' AS stock, [date], close_price FROM dbo.[Bajaj Auto]
    UNION ALL SELECT 'Eicher Motors', [date], close_price FROM dbo.[Eicher Motors]
    UNION ALL SELECT 'Hero Motocorp', [date], close_price FROM dbo.hero_motocorp
    UNION ALL SELECT 'Infosys', [date], close_price FROM dbo.infosys
    UNION ALL SELECT 'TCS', [date], close_price FROM dbo.tcs
    UNION ALL SELECT 'TVS Motors', [date], close_price FROM dbo.tvs_motors
),
ma AS (
    SELECT stock, [date], close_price,
           ROW_NUMBER() OVER (PARTITION BY stock ORDER BY [date]) AS rn,
           AVG(CAST(close_price AS DECIMAL(18,6))) OVER (
               PARTITION BY stock ORDER BY [date] ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
           ) AS raw_ma20,
           AVG(CAST(close_price AS DECIMAL(18,6))) OVER (
               PARTITION BY stock ORDER BY [date] ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
           ) AS raw_ma50
    FROM prices
),
ma_ready AS (
    SELECT stock, [date], close_price,
           CASE WHEN rn >= 20 THEN raw_ma20 END AS ma20,
           CASE WHEN rn >= 50 THEN raw_ma50 END AS ma50
    FROM ma
),
lagged AS (
    SELECT stock, [date], close_price, ma20, ma50,
           LAG(ma20) OVER (PARTITION BY stock ORDER BY [date]) AS prev_ma20,
           LAG(ma50) OVER (PARTITION BY stock ORDER BY [date]) AS prev_ma50
    FROM ma_ready
),
sig AS (
    SELECT stock, [date], close_price,
           CASE
               WHEN ma20 IS NULL OR ma50 IS NULL
                 OR prev_ma20 IS NULL OR prev_ma50 IS NULL THEN 'Hold'
               WHEN ma20 > ma50 AND prev_ma20 <= prev_ma50 THEN 'Buy'
               WHEN ma20 < ma50 AND prev_ma20 >= prev_ma50 THEN 'Sell'
               ELSE 'Hold'
           END AS [signal]
    FROM lagged
),
latest AS (
    SELECT stock, [date] AS last_signal_date, [signal] AS last_signal,
           ROW_NUMBER() OVER (PARTITION BY stock ORDER BY [date] DESC) AS rn
    FROM sig
    WHERE [signal] <> 'Hold'
)
SELECT s.stock,
       SUM(CASE WHEN s.[signal] = 'Buy' THEN 1 ELSE 0 END) AS buys,
       SUM(CASE WHEN s.[signal] = 'Sell' THEN 1 ELSE 0 END) AS sells,
       l.last_signal_date,
       l.last_signal
INTO dbo.all_stock_signals
FROM sig s
LEFT JOIN latest l ON l.stock = s.stock AND l.rn = 1
GROUP BY s.stock, l.last_signal_date, l.last_signal;

SELECT * FROM dbo.all_stock_signals ORDER BY stock;

-- TASK 11: First-to-last close percentage change (raw prices; corporate actions may distort it)
WITH prices AS (
    SELECT 'Bajaj Auto' AS stock, [date], close_price FROM dbo.[Bajaj Auto]
    UNION ALL SELECT 'Eicher Motors', [date], close_price FROM dbo.[Eicher Motors]
    UNION ALL SELECT 'Hero Motocorp', [date], close_price FROM dbo.hero_motocorp
    UNION ALL SELECT 'Infosys', [date], close_price FROM dbo.infosys
    UNION ALL SELECT 'TCS', [date], close_price FROM dbo.tcs
    UNION ALL SELECT 'TVS Motors', [date], close_price FROM dbo.tvs_motors
),
ends AS (
    SELECT stock, MIN([date]) AS first_date, MAX([date]) AS last_date
    FROM prices GROUP BY stock
)
SELECT p.stock,
       ROUND(CAST(firstp.close_price AS DECIMAL(18,4)), 2) AS first_close,
       ROUND(CAST(lastp.close_price AS DECIMAL(18,4)), 2) AS last_close,
       ROUND(100.0 * (CAST(lastp.close_price AS DECIMAL(18,6)) /
                      NULLIF(CAST(firstp.close_price AS DECIMAL(18,6)), 0) - 1), 1) AS pct_change
FROM ends e
JOIN prices firstp ON firstp.stock = e.stock AND firstp.[date] = e.first_date
JOIN prices lastp ON lastp.stock = e.stock AND lastp.[date] = e.last_date
JOIN (SELECT DISTINCT stock FROM prices) p ON p.stock = e.stock
ORDER BY pct_change DESC;

-- TASK 12: Worst day-over-day percentage move for each stock
WITH prices AS (
    SELECT 'Bajaj Auto' AS stock, [date], close_price FROM dbo.[Bajaj Auto]
    UNION ALL SELECT 'Eicher Motors', [date], close_price FROM dbo.[Eicher Motors]
    UNION ALL SELECT 'Hero Motocorp', [date], close_price FROM dbo.Hero_Motocorp
    UNION ALL SELECT 'Infosys', [date], close_price FROM dbo.infosys
    UNION ALL SELECT 'TCS', [date], close_price FROM dbo.tcs
    UNION ALL SELECT 'TVS Motors', [date], close_price FROM dbo.tvs_motors
),
moves AS (
    SELECT stock, [date], close_price,
           LAG(close_price) OVER (PARTITION BY stock ORDER BY [date]) AS prev_close
    FROM prices
),
ranked AS (
    SELECT stock, [date], close_price,
           ROUND(100.0 * (CAST(close_price AS DECIMAL(18,6)) /
                          NULLIF(CAST(prev_close AS DECIMAL(18,6)), 0) - 1), 1) AS pct_move,
           ROW_NUMBER() OVER (
               PARTITION BY stock
               ORDER BY (CAST(close_price AS DECIMAL(18,6)) /
                         NULLIF(CAST(prev_close AS DECIMAL(18,6)), 0) - 1) ASC
           ) AS rn
    FROM moves
    WHERE prev_close IS NOT NULL
)
SELECT stock, [date], close_price, pct_move
FROM ranked
WHERE rn = 1
ORDER BY pct_move ASC;

-- TASK 13: Adjust TCS and Infosys for 1:1 bonus issues, then compare first and last closes.
-- VERIFY these event dates against your Task 12 findings and source data before using results.
WITH adjusted AS (
    SELECT 'TCS' AS stock, [date],
           CASE WHEN [date] < '2018-06-28'
                THEN CAST(close_price AS DECIMAL(18,6)) / 2.0
                ELSE CAST(close_price AS DECIMAL(18,6)) END AS adj_close
    FROM dbo.tcs
    UNION ALL
    SELECT 'Infosys', [date],
           CASE WHEN [date] < '2015-06-15'
                THEN CAST(close_price AS DECIMAL(18,6)) / 2.0
                ELSE CAST(close_price AS DECIMAL(18,6)) END AS adj_close
    FROM dbo.infosys
),
ends AS (
    SELECT stock, MIN([date]) AS first_date, MAX([date]) AS last_date
    FROM adjusted GROUP BY stock
)
SELECT a.stock,
       ROUND(100.0 * (
           MAX(CASE WHEN a.[date] = e.last_date THEN a.adj_close END) /
           NULLIF(MAX(CASE WHEN a.[date] = e.first_date THEN a.adj_close END), 0) - 1
       ), 1) AS adjusted_pct_change
FROM adjusted a
JOIN ends e ON e.stock = a.stock
GROUP BY a.stock
ORDER BY a.stock;

-- FINAL VALIDATION: row counts for the six source tables
SELECT 'bajaj_auto' AS stock, COUNT(*) AS rows_count FROM dbo.[Bajaj Auto]
UNION ALL SELECT 'eicher_motors', COUNT(*) FROM dbo.[Eicher Motors]
UNION ALL SELECT 'hero_motocorp', COUNT(*) FROM dbo.hero_motocorp
UNION ALL SELECT 'infosys', COUNT(*) FROM dbo.infosys
UNION ALL SELECT 'tcs', COUNT(*) FROM dbo.tcs
UNION ALL SELECT 'tvs_motors', COUNT(*) FROM dbo.tvs_motors;


