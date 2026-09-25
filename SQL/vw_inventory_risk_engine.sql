USE supply_chain;

CREATE OR REPLACE VIEW vw_inventory_risk_engine AS

WITH inventory_details AS (
    SELECT 
        w.warehouse_id,
        p.product_id,
        p.reorder_point,
        iob.opening_units,

        COALESCE(SUM(im.quantity_change), 0) AS net_movement,

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

        opening_units + net_movement AS current_inventory,

        (opening_units + net_movement) - reorder_point AS stock_gap

    FROM inventory_details
),

inventory_score AS (
    SELECT
        *,
        CASE
            WHEN current_inventory <= 0 THEN 40
            WHEN current_inventory < reorder_point THEN 30
            WHEN current_inventory < reorder_point * 1.25 THEN 20
            ELSE 0
        END AS inventory_score

    FROM inventory_analysis
),

consumption_score AS (
    SELECT
        *,
        CASE
            WHEN total_units_consumed > reorder_point * 2 THEN 30
            WHEN total_units_consumed > reorder_point THEN 20
            ELSE 0
        END AS consumption_score

    FROM inventory_score
),

gap_score AS (
    SELECT
        *,
        CASE
            WHEN stock_gap < -reorder_point THEN 30
            WHEN stock_gap < 0 THEN 20
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
            WHEN total_risk_score >= 80 THEN 'Critical'
            WHEN total_risk_score >= 60 THEN 'High'
            WHEN total_risk_score >= 40 THEN 'Medium'
            WHEN total_risk_score >= 20 THEN 'Watch'
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

FROM final_risk_engine;

SELECT *
FROM vw_inventory_risk_engine
LIMIT 20;
SELECT COUNT(*) AS risk_items
FROM vw_inventory_risk_engine;