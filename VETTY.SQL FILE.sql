CREATE DATABASE sql_test;
USE sql_test;

CREATE TABLE transactions (
    buyer_id INT,
    purchase_time DATETIME,
    refund_item DATETIME NULL,
    store_id VARCHAR(10),
    item_id VARCHAR(10),
    gross_transaction_value DECIMAL(10,2)
);

CREATE TABLE items (
    store_id VARCHAR(10),
    item_id VARCHAR(10),
    item_category VARCHAR(50),
    item_name VARCHAR(50)
);

INSERT INTO transactions VALUES
(3, '2019-09-19 21:19:06', NULL, 'a', 'a1', 58),
(12, '2019-12-10 20:10:14', '2019-12-15 23:19:06', 'b', 'b2', 475),
(3, '2020-02-01 23:59:46', '2020-09-02 21:22:06', 'f', 'f2', 91),
(2, '2020-04-30 20:19:06', NULL, 'd', 'd3', 2500),
(8, '2020-04-06 12:10:22', NULL, 'e', 'e7', 24),
(3, '2019-09-23 12:09:35', '2019-09-27 02:55:02', 'g', 'g6', 61);

INSERT INTO items VALUES
('a','a1','pants','denim pants'),
('a','a2','tops','blouse'),
('f','f1','table','coffee table'),
('f','f2','chair','lounge chair'),
('d','d3','chair','armchair'),
('e','e7','jewelry','bracelet'),
('b','b4','earphone','airpods');

-- 1) Count of purchases per month (excluding refunded purchases
SELECT 
    DATE_FORMAT(purchase_time, '%Y-%m') AS month,
    COUNT(*) AS purchase_count
FROM transactions
WHERE refund_item IS NULL
GROUP BY DATE_FORMAT(purchase_time, '%Y-%m')
ORDER BY month;
-- EXPLANATION This query groups all sccuessful purchases by month to understand how many valid sales happened each month. Refunds are filtered out using refund_item is null. The goal is to analyze monthly customer activity and sales trends.

-- 2) How many stores receive at least 5 orders/transactions in October 2020?
SELECT store_id,
       COUNT(*) AS orders_in_oct_2020
FROM transactions
WHERE purchase_time >= '2020-10-01'
  AND purchase_time <  '2020-11-01'
-- include or exclude refunds as needed; below excludes refunded transactions
  AND refund_item IS NULL
GROUP BY store_id
HAVING COUNT(*) >= 5;
-- EXPLANATION This query checks the store performance during a specific month.we filter transcations based on th date range and count the number of orders each store received.Only those stores meet or exceed the threshold of 5orders are selected.


-- 3) For each store, shortest interval (in minutes) from purchase to refund time
SELECT
  store_id,
  MIN(TIMESTAMPDIFF(MINUTE, purchase_time, refund_item)) AS min_refund_interval_minutes
FROM transactions
WHERE refund_item IS NOT NULL
GROUP BY store_id;
-- EXPLANATION We calculate how long each refunded transcation took from purchase to refund time. TIMESTAMPDIFF() is used to find the difference in minutes. For each store we take the minimum refund duration, Indicating the fastest refund processing time.


-- 4) Gross transaction value of every store’s first order
WITH first_order AS (
  SELECT
    store_id,
    gross_transaction_value,
    purchase_time,
    ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY purchase_time) AS rn
  FROM transactions
)
SELECT store_id, gross_transaction_value, purchase_time
FROM first_order
WHERE rn = 1
ORDER BY store_id;
-- EXPLANATION In this we find the very first order placed at each store based on purchase_time. Using ranking ROW_NUMBER , identitfy the earliest transcation and return its order value.


-- 5) Most popular item_name that buyers order on their FIRST purchase
WITH first_purchase AS (
  SELECT
    buyer_id,
    item_id,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS rn
  FROM transactions
  WHERE refund_item IS NULL    
)
SELECT i.item_name,
       COUNT(*) AS first_purchase_count
FROM first_purchase fp
JOIN items i ON fp.item_id = i.item_id
WHERE fp.rn = 1
GROUP BY i.item_name
ORDER BY first_purchase_count DESC
LIMIT 1;
-- EXPLANATION Every buyers first non refunded purchase is identified and the item they bought is extracted. Then we count how many buyers bought each item as their first purchase. The most frequently occuring item is considered the most popular first purchase.


-- 6) Create a flag indicating whether the refund can be processed (within 72 hours)
SELECT
  *,
  CASE
    WHEN refund_item IS NULL THEN 'no_refund'
    WHEN TIMESTAMPDIFF(HOUR, purchase_time, refund_item) <= 72 THEN 'processed'
    ELSE 'not_processed'
  END AS refund_flag
FROM transactions;
-- EXPLANATION A refund considered 'processed' only if the time difference between purchase and refund is <= 72 hours.


-- 7) Create a rank by buyer_id and filter for only the second purchase per buyer (ignore refunds)
WITH ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS purchase_rank
  FROM transactions
  WHERE refund_item IS NULL   -- ignore refunds
)
SELECT *
FROM ranked
WHERE purchase_rank = 2;
-- EXPLANATION Using window functions, each buyes valid purchases are sorted by purchase time. ROW_NUMBER() assigns a rank to each transcations, and the query extracts only the second purchase.



-- 8) Find the second transaction time per buyer (don’t use MIN/MAX; include all transactions)
WITH ordered_txn AS (
  SELECT
    buyer_id,
    purchase_time,
    ROW_NUMBER() OVER (PARTITION BY buyer_id ORDER BY purchase_time) AS rn
  FROM transactions
)
SELECT buyer_id,
       purchase_time AS second_purchase_time
FROM ordered_txn
WHERE rn = 2;
--EXPLANATION This query identifies the second transcations of every buyer based purely on chronological order. It used ROW_NUMBER() to rank all the purchases and select the one with rank = 2.


-- note 
-- In this excercise we used SQL to analyze a small retail transcation dataset. We explored purchase patterns, refund behaviour and customer buying trends. By filtering, grouping and ranking data, we indentified monthly ourchase counts, store performance and fastest refund intervals.

