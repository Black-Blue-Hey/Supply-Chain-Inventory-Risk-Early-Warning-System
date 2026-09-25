-- =========================================================
-- DATABASE SETUP
-- =========================================================

CREATE DATABASE Supply_chain;

SET GLOBAL local_infile = 1;

USE supply_chain;


-- =========================================================
-- TABLE CREATION
-- =========================================================

-- 1. SUPPLIERS
CREATE TABLE suppliers (
    supplier_id VARCHAR(20) NOT NULL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    country_code VARCHAR(10) NOT NULL,
    lead_time_days INT NOT NULL,
    reliability_score DECIMAL(5,3) NOT NULL
);


-- 2. WAREHOUSES
CREATE TABLE warehouses (
    warehouse_id VARCHAR(20) NOT NULL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    region VARCHAR(50) NOT NULL,
    capacity_units INT NOT NULL
);


-- 3. PRODUCTS
CREATE TABLE products (
    product_id VARCHAR(20) NOT NULL PRIMARY KEY,
    supplier_id VARCHAR(20) NOT NULL,
    sku VARCHAR(30) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    unit_cost DECIMAL(12,2) NOT NULL,
    reorder_point INT NOT NULL
);


-- 4. PURCHASE ORDERS
CREATE TABLE purchase_orders (
    purchase_order_id VARCHAR(30) NOT NULL PRIMARY KEY,
    supplier_id VARCHAR(20) NOT NULL,
    warehouse_id VARCHAR(20) NOT NULL,
    ordered_at DATETIME NOT NULL,
    expected_at DATETIME NOT NULL,
    received_at DATETIME NULL,
    status VARCHAR(30) NOT NULL
);


-- 5. PURCHASE ORDER LINES
CREATE TABLE purchase_order_lines (
    purchase_order_line_id VARCHAR(30) NOT NULL PRIMARY KEY,
    purchase_order_id VARCHAR(30) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    quantity_ordered INT NOT NULL,
    quantity_received INT NOT NULL,
    unit_cost DECIMAL(12,2) NOT NULL
);


-- 6. INVENTORY OPENING BALANCES
CREATE TABLE inventory_opening_balances (
    opening_balance_id VARCHAR(40) NOT NULL PRIMARY KEY,
    product_id VARCHAR(20) NOT NULL,
    warehouse_id VARCHAR(20) NOT NULL,
    balance_date DATE NOT NULL,
    opening_units INT NOT NULL,
    UNIQUE (product_id, warehouse_id)
);


-- 7. INVENTORY MOVEMENTS
CREATE TABLE inventory_movements (
    movement_id VARCHAR(30) NOT NULL PRIMARY KEY,
    product_id VARCHAR(20) NOT NULL,
    warehouse_id VARCHAR(20) NOT NULL,
    movement_at DATETIME NOT NULL,
    movement_type VARCHAR(30) NOT NULL,
    quantity_change INT NOT NULL,
    purchase_order_line_id VARCHAR(30) NULL,
    transfer_id VARCHAR(30) NULL
);


-- =========================================================
-- DATA IMPORT
-- =========================================================

USE supply_chain;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/inventory_movements.csv'
INTO TABLE inventory_movements
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/inventory_opening_balances.csv'
INTO TABLE inventory_opening_balances
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/purchase_order_lines.csv'
INTO TABLE purchase_order_lines
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/purchase_orders.csv'
INTO TABLE purchase_orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    purchase_order_id,
    supplier_id,
    warehouse_id,
    @ordered_at,
    @expected_at,
    @received_at,
    status
)
SET
    ordered_at = STR_TO_DATE(@ordered_at, '%d-%m-%Y'),
    expected_at = STR_TO_DATE(@expected_at, '%d-%m-%Y'),
    received_at = STR_TO_DATE(
        NULLIF(@received_at, ''),
        '%d-%m-%Y'
    );


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/suppliers.csv'
INTO TABLE suppliers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL INFILE
'F:/New folder/supply chain analysis/files/warehouses.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- =========================================================
-- DATA VALIDATION
-- =========================================================

SELECT
    'suppliers' AS table_name,
    COUNT(*) AS no_of_rows
FROM suppliers

UNION ALL

SELECT
    'warehouses',
    COUNT(*)
FROM warehouses

UNION ALL

SELECT
    'products',
    COUNT(*)
FROM products

UNION ALL

SELECT
    'purchase_orders',
    COUNT(*)
FROM purchase_orders

UNION ALL

SELECT
    'purchase_order_lines',
    COUNT(*)
FROM purchase_order_lines

UNION ALL

SELECT
    'inventory_opening_balances',
    COUNT(*)
FROM inventory_opening_balances

UNION ALL

SELECT
    'inventory_movements',
    COUNT(*)
FROM inventory_movements;


-- =========================================================
-- DATA CLEANING
-- =========================================================

UPDATE purchase_orders
SET status = REPLACE(status, CHAR(13), '');


-- =========================================================
-- QUESTION 1
-- =========================================================

-- Q1. Which suppliers have the highest delivery risk based on
-- late delivery rate, average delay, and maximum delay?

WITH supplier_performance AS (

    SELECT
        s.supplier_id,
        s.supplier_name,
        s.country_code,
        s.reliability_score,

        COUNT(po.purchase_order_id) AS total_pos,

        COUNT(
            CASE
                WHEN po.status = 'received'
                THEN po.purchase_order_id
            END
        ) AS received_pos,

        COUNT(
            CASE
                WHEN po.status = 'received'
                     AND po.received_at > po.expected_at
                THEN po.purchase_order_id
            END
        ) AS late_pos,

        AVG(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.expected_at
                )
            END
        ) AS avg_delay_days,

        MAX(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.expected_at
                )
            END
        ) AS max_delay_days

    FROM suppliers s

    JOIN purchase_orders po
        ON s.supplier_id = po.supplier_id

    WHERE po.status <> 'cancelled'

    GROUP BY
        s.supplier_id,
        s.supplier_name,
        s.country_code,
        s.reliability_score
),

supplier_metrics AS (

    SELECT
        *,
        (late_pos / received_pos) * 100 AS late_delivery_rate

    FROM supplier_performance

    WHERE received_pos >= 20
)

SELECT
    supplier_id,
    supplier_name,
    country_code,
    reliability_score,
    total_pos,
    received_pos,
    late_pos,
    late_delivery_rate,
    avg_delay_days,
    max_delay_days,

    RANK() OVER (
        ORDER BY late_delivery_rate DESC
    ) AS late_rate_rank,

    RANK() OVER (
        ORDER BY avg_delay_days DESC
    ) AS avg_delay_rank

FROM supplier_metrics

ORDER BY late_rate_rank;


-- =========================================================
-- QUESTION 2
-- =========================================================

-- Q2. Which products are at risk of stockout or falling below
-- their reorder point at each warehouse?

WITH product_movement AS (

    SELECT
        p.product_id,
        p.sku,
        p.category,
        p.reorder_point,
        ob.warehouse_id,
        ob.opening_units,

        COALESCE(
            SUM(im.quantity_change),
            0
        ) AS net_movement

    FROM inventory_opening_balances ob

    JOIN products p
        ON ob.product_id = p.product_id

    LEFT JOIN inventory_movements im
        ON im.product_id = ob.product_id
        AND im.warehouse_id = ob.warehouse_id

    GROUP BY
        p.product_id,
        p.sku,
        p.category,
        p.reorder_point,
        ob.warehouse_id,
        ob.opening_units
),

inventory_analysis AS (

    SELECT
        product_id,
        warehouse_id,
        sku,
        category,
        opening_units,
        reorder_point,
        net_movement,

        opening_units + net_movement AS current_inventory

    FROM product_movement
)

SELECT
    product_id,
    warehouse_id,
    sku,
    category,
    opening_units,
    net_movement,
    current_inventory,
    reorder_point,

    current_inventory - reorder_point AS stock_gap,

    CASE
        WHEN current_inventory <= 0
            THEN 'out_of_stock'

        WHEN current_inventory < reorder_point
            THEN 'Below reorder point'

        WHEN current_inventory <= reorder_point * 1.25
            THEN 'near reorder point'

        ELSE 'healthy'
    END AS stock_status

FROM inventory_analysis

ORDER BY
    CASE
        WHEN current_inventory <= 0 THEN 1
        WHEN current_inventory < reorder_point THEN 2
        WHEN current_inventory <= reorder_point * 1.25 THEN 3
        ELSE 4
    END,
    stock_gap;


-- =========================================================
-- QUESTION 3
-- =========================================================

-- Q3. Which suppliers create the highest dependency risk because
-- they supply many products and have weak delivery performance?

WITH supplier_details AS (

    SELECT
        s.supplier_id,
        s.supplier_name,
        s.reliability_score,

        COUNT(DISTINCT p.product_id) AS product_count,

        COUNT(
            CASE
                WHEN po.status = 'received'
                THEN po.purchase_order_id
            END
        ) AS total_pos,

        COUNT(
            CASE
                WHEN po.status = 'received'
                     AND po.received_at > po.expected_at
                THEN po.purchase_order_id
            END
        ) AS late_pos,

        AVG(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.expected_at
                )
            END
        ) AS avg_delay_days

    FROM products p

    LEFT JOIN suppliers s
        ON p.supplier_id = s.supplier_id

    JOIN purchase_orders po
        ON s.supplier_id = po.supplier_id

    GROUP BY
        s.supplier_id,
        s.supplier_name,
        s.reliability_score
),

supplier_dependency AS (

    SELECT
        *,
        (late_pos / total_pos) * 100 AS late_delivery_rate,
        COUNT(*) OVER () AS total_suppliers

    FROM supplier_details
),

ranks AS (

    SELECT
        *,
        RANK() OVER (
            ORDER BY product_count DESC
        ) AS product_rank,

        RANK() OVER (
            ORDER BY late_delivery_rate DESC
        ) AS late_delivery_rank

    FROM supplier_dependency
)

SELECT
    supplier_id,
    supplier_name,
    reliability_score,
    product_count,
    total_pos,
    late_pos,
    avg_delay_days,
    late_delivery_rate,

    CASE
        WHEN product_rank <= CEIL(total_suppliers * 0.20)
             AND late_delivery_rank <= CEIL(total_suppliers * 0.20)
            THEN 'High'

        WHEN product_rank <= CEIL(total_suppliers * 0.20)
             OR late_delivery_rank <= CEIL(total_suppliers * 0.20)
            THEN 'Medium'

        ELSE 'Low'
    END AS risk_level

FROM ranks

ORDER BY risk_level;


-- =========================================================
-- QUESTION 4
-- =========================================================

-- Q4. Which suppliers have the lowest purchase-order fulfillment
-- rates and the largest quantity shortfalls?

SELECT
    s.supplier_id,
    s.supplier_name,

    COUNT(*) AS total_po_lines,

    SUM(pol.quantity_ordered) AS ordered_qty,

    SUM(pol.quantity_received) AS received_qty,

    AVG(pol.unit_cost) AS avg_unit_cost,

    SUM(pol.quantity_ordered)
        - SUM(pol.quantity_received) AS quantity_shortfall,

    (
        SUM(pol.quantity_received)
        / SUM(pol.quantity_ordered)
    ) * 100 AS fulfillment_rate,

    COUNT(
        CASE
            WHEN pol.quantity_received = 0
            THEN 1
        END
    ) AS unfulfilled_orders,

    COUNT(
        CASE
            WHEN pol.quantity_received > 0
                 AND pol.quantity_received < pol.quantity_ordered
            THEN 1
        END
    ) AS partially_filled_orders

FROM suppliers s

JOIN purchase_orders po
    ON s.supplier_id = po.supplier_id

JOIN purchase_order_lines pol
    ON po.purchase_order_id = pol.purchase_order_id

WHERE po.status <> 'cancelled'

GROUP BY
    s.supplier_id,
    s.supplier_name

ORDER BY fulfillment_rate ASC;


-- =========================================================
-- QUESTION 5
-- =========================================================

-- Q5. Which warehouses have the highest inventory risk based on
-- inventory utilization, products below reorder point, and stockouts?

WITH warehouse_details AS (

    SELECT
        w.warehouse_id,
        w.warehouse_name,
        w.region,
        w.capacity_units,
        iob.product_id,
        p.reorder_point,
        iob.opening_units,

        COALESCE(
            SUM(im.quantity_change),
            0
        ) AS net_movement

    FROM inventory_opening_balances iob

    LEFT JOIN inventory_movements im
        ON iob.product_id = im.product_id
        AND iob.warehouse_id = im.warehouse_id

    JOIN products p
        ON p.product_id = iob.product_id

    JOIN warehouses w
        ON w.warehouse_id = iob.warehouse_id

    GROUP BY
        w.warehouse_id,
        w.warehouse_name,
        w.region,
        w.capacity_units,
        iob.product_id,
        p.reorder_point,
        iob.opening_units
),

inventory AS (

    SELECT
        *,
        opening_units + net_movement AS current_inventory

    FROM warehouse_details
),

inventory_details AS (

    SELECT
        warehouse_id,
        warehouse_name,
        region,
        capacity_units,

        COUNT(DISTINCT product_id) AS total_products,

        SUM(current_inventory) AS current_inventory,

        COUNT(
            CASE
                WHEN current_inventory <= 0
                THEN 1
            END
        ) AS products_out_of_stock,

        COUNT(
            CASE
                WHEN current_inventory < reorder_point
                THEN 1
            END
        ) AS products_below_reorder,

        (
            SUM(current_inventory)
            / capacity_units
        ) * 100 AS inventory_utilization_percentage

    FROM inventory

    GROUP BY
        warehouse_id,
        warehouse_name,
        region,
        capacity_units
)

SELECT
    warehouse_id,
    warehouse_name,
    region,
    capacity_units,
    total_products,
    current_inventory,
    products_below_reorder,
    products_out_of_stock,
    inventory_utilization_percentage

FROM inventory_details

ORDER BY inventory_utilization_percentage DESC;


-- =========================================================
-- QUESTION 6
-- =========================================================

-- Q6. Which suppliers consistently deliver later than their
-- expected lead time?

WITH supplier_details AS (

    SELECT
        s.supplier_id,
        s.supplier_name,
        s.lead_time_days,

        COUNT(
            CASE
                WHEN po.status = 'received'
                THEN po.purchase_order_id
            END
        ) AS total_pos,

        COUNT(
            CASE
                WHEN po.status = 'received'
                     AND po.received_at > po.expected_at
                THEN po.purchase_order_id
            END
        ) AS late_pos,

        AVG(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.expected_at
                )
            END
        ) AS avg_delay_days,

        MAX(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.expected_at
                )
            END
        ) AS max_delay_days,

        AVG(
            CASE
                WHEN po.status = 'received'
                THEN DATEDIFF(
                    po.received_at,
                    po.ordered_at
                )
            END
        ) AS avg_actual_delivery_days

    FROM suppliers s

    JOIN purchase_orders po
        ON s.supplier_id = po.supplier_id

    GROUP BY
        s.supplier_id,
        s.supplier_name,
        s.lead_time_days
),

delay_analysis AS (

    SELECT
        *,
        (
            late_pos / NULLIF(total_pos, 0)
        ) * 100.0 AS late_delivery_rate,

        avg_actual_delivery_days - lead_time_days
            AS lead_time_gap

    FROM supplier_details
)

SELECT
    supplier_id,
    supplier_name,
    lead_time_days,
    total_pos,
    late_pos,
    late_delivery_rate,
    avg_delay_days,
    max_delay_days,
    avg_actual_delivery_days,
    lead_time_gap

FROM delay_analysis

ORDER BY lead_time_gap DESC;


-- =========================================================
-- QUESTION 7
-- =========================================================

-- Q7. How does supplier delivery delay change month by month?

WITH month_analysis AS (

    SELECT
        DATE_FORMAT(
            received_at,
            '%Y-%m'
        ) AS month_label,

        COUNT(
            CASE
                WHEN status = 'received'
                THEN purchase_order_id
            END
        ) AS total_received_pos,

        COUNT(
            CASE
                WHEN status = 'received'
                     AND received_at > expected_at
                THEN purchase_order_id
            END
        ) AS late_pos,

        COUNT(
            CASE
                WHEN status = 'received'
                     AND received_at <= expected_at
                THEN purchase_order_id
            END
        ) AS on_time_pos,

        AVG(
            DATEDIFF(
                received_at,
                expected_at
            )
        ) AS avg_delay_days,

        MAX(
            DATEDIFF(
                received_at,
                expected_at
            )
        ) AS max_delay_days

    FROM purchase_orders

    GROUP BY month_label
)

SELECT
    month_label,
    total_received_pos,
    late_pos,
    on_time_pos,
    avg_delay_days,
    max_delay_days,

    (
        late_pos
        / NULLIF(total_received_pos, 0)
    ) * 100.0 AS late_delivery_rate

FROM month_analysis

ORDER BY late_delivery_rate DESC;


-- =========================================================
-- QUESTION 8
-- =========================================================

-- Q8. Which products and warehouses have the highest inventory
-- consumption and demand intensity?

WITH warehouse_details AS (

    SELECT
        w.warehouse_id,
        w.warehouse_name,
        w.region,
        p.product_id,
        p.sku,
        p.category,
        p.reorder_point,

        SUM(
            CASE
                WHEN im.quantity_change < 0
                THEN ABS(im.quantity_change)
            END
        ) AS total_units_consumed,

        COUNT(
            CASE
                WHEN im.movement_type = 'sale'
                THEN im.movement_id
            END
        ) AS sales_transactions

    FROM warehouses w

    JOIN inventory_movements im
        ON w.warehouse_id = im.warehouse_id

    JOIN products p
        ON p.product_id = im.product_id

    GROUP BY
        w.warehouse_id,
        w.warehouse_name,
        w.region,
        p.product_id,
        p.sku,
        p.category,
        p.reorder_point
),

product_consumption AS (

    SELECT
        *,
        total_units_consumed
            / sales_transactions AS avg_units_per_sale,

        total_units_consumed
            / NULLIF(reorder_point, 0)
            AS consumption_to_reorder_ratio

    FROM warehouse_details
)

SELECT
    warehouse_id,
    warehouse_name,
    region,
    product_id,
    sku,
    category,
    total_units_consumed,
    sales_transactions,
    avg_units_per_sale,
    reorder_point,
    consumption_to_reorder_ratio

FROM product_consumption

ORDER BY consumption_to_reorder_ratio DESC;


-- =========================================================
-- QUESTION 9
-- =========================================================

-- Q9. Which product-warehouse combinations should be prioritized
-- based on current inventory, consumption, and reorder-point risk?

WITH inventory_details AS (

    SELECT
        w.warehouse_id,
        p.product_id,
        p.reorder_point,
        iob.opening_units,

        COALESCE(
            SUM(im.quantity_change),
            0
        ) AS net_movement,

        SUM(
            CASE
                WHEN im.movement_type = 'sale'
                THEN ABS(im.quantity_change)
            END
        ) AS total_units_consumed

    FROM inventory_opening_balances iob

    LEFT JOIN inventory_movements im
        ON iob.product_id = im.product_id
        AND iob.warehouse_id = im.warehouse_id

    JOIN products p
        ON p.product_id = iob.product_id

    JOIN warehouses w
        ON w.warehouse_id = iob.warehouse_id

    GROUP BY
        w.warehouse_id,
        p.product_id,
        p.reorder_point,
        iob.opening_units
),

inventory_analysis AS (

    SELECT
        *,
        opening_units + net_movement
            AS current_inventory

    FROM inventory_details
)

SELECT
    warehouse_id,
    product_id,
    current_inventory,
    reorder_point,
    total_units_consumed,

    current_inventory - reorder_point
        AS stock_gap,

    CASE
        WHEN current_inventory <= 0
            THEN 'Critical'

        WHEN current_inventory < reorder_point
             AND total_units_consumed > reorder_point
            THEN 'High'

        WHEN current_inventory < reorder_point
            THEN 'Medium'

        WHEN current_inventory >= reorder_point
             AND total_units_consumed > reorder_point
            THEN 'Watch'

        ELSE 'Low'
    END AS inventory_risk

FROM inventory_analysis

ORDER BY
    CASE inventory_risk
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Watch' THEN 4
        WHEN 'Low' THEN 5
    END;


-- =========================================================
-- QUESTION 10
-- =========================================================

-- Q10. How can we build a rule-based inventory early-warning
-- engine that assigns a 0–100 risk score to every
-- product-warehouse combination?

WITH inventory_details AS (

    SELECT
        w.warehouse_id,
        p.product_id,
        p.reorder_point,
        iob.opening_units,

        COALESCE(
            SUM(im.quantity_change),
            0
        ) AS net_movement,

        COALESCE(
            SUM(
                CASE
                    WHEN im.movement_type = 'sale'
                    THEN ABS(im.quantity_change)
                    ELSE 0
                END
            ),
            0
        ) AS total_units_consumed

    FROM inventory_opening_balances iob

    LEFT JOIN inventory_movements im
        ON iob.product_id = im.product_id
        AND iob.warehouse_id = im.warehouse_id

    JOIN products p
        ON p.product_id = iob.product_id

    JOIN warehouses w
        ON w.warehouse_id = iob.warehouse_id

    GROUP BY
        w.warehouse_id,
        p.product_id,
        p.reorder_point,
        iob.opening_units
),

inventory_analysis AS (

    SELECT
        warehouse_id,
        product_id,
        reorder_point,
        opening_units,
        total_units_consumed,

        opening_units + net_movement
            AS current_inventory,

        (
            opening_units + net_movement
        ) - reorder_point AS stock_gap

    FROM inventory_details
),

inventory_score AS (

    SELECT
        *,

        CASE
            WHEN current_inventory <= 0
                THEN 40

            WHEN current_inventory < reorder_point
                THEN 30

            WHEN current_inventory < reorder_point * 1.25
                THEN 15

            ELSE 0
        END AS inventory_score

    FROM inventory_analysis
),

consumption_score AS (

    SELECT
        *,

        CASE
            WHEN total_units_consumed > reorder_point * 2
                THEN 30

            WHEN total_units_consumed > reorder_point
                THEN 20

            ELSE 0
        END AS consumption_score

    FROM inventory_score
),

gap_score AS (

    SELECT
        *,

        CASE
            WHEN stock_gap < -reorder_point
                THEN 30

            WHEN stock_gap < 0
                THEN 20

            ELSE 0
        END AS gap_score

    FROM consumption_score
),

risk_engine AS (

    SELECT
        warehouse_id,
        product_id,
        current_inventory,
        reorder_point,
        total_units_consumed,
        stock_gap,
        inventory_score,
        consumption_score,
        gap_score,

        inventory_score
            + consumption_score
            + gap_score AS total_risk_score

    FROM gap_score
),

final_risk_engine AS (

    SELECT
        *,

        CASE
            WHEN total_risk_score >= 80
                THEN 'Critical'

            WHEN total_risk_score >= 60
                THEN 'High'

            WHEN total_risk_score >= 40
                THEN 'Medium'

            WHEN total_risk_score >= 20
                THEN 'Watch'

            ELSE 'Low'
        END AS risk_level

    FROM risk_engine
)

SELECT
    warehouse_id,
    product_id,
    current_inventory,
    reorder_point,
    total_units_consumed,
    stock_gap,
    inventory_score,
    consumption_score,
    gap_score,
    total_risk_score,
    risk_level

FROM final_risk_engine

ORDER BY
    CASE risk_level
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Watch' THEN 4
        WHEN 'Low' THEN 5
    END,
    total_risk_score DESC,
    stock_gap ASC;