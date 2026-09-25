# Supply Chain Inventory Risk & Early-Warning System

## Overview

An end-to-end supply chain analytics project designed to identify inventory risks, stock shortages, supplier delivery delays, and purchase order fulfillment issues.

**Workflow:**  
Excel Data Validation → MySQL/SQL Analysis → Inventory Risk Engine → Power BI Dashboard

## Dataset

Synthetic **Inventory & Supply Chain Dataset v1.0.0** created by Analytics Engineering.

- 2,500 products
- 250 suppliers
- 12 warehouses
- 18,000 purchase orders
- 53,967 purchase order lines
- 138,436 inventory movements
- 30,000 product–warehouse combinations

**Attribution:** Analytics Engineering, "Inventory & Supply Chain Dataset v1.0.0"  
Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)  
Source: https://www.analyticsengineering.com/datasets/inventory-supply-chain

## Tools

- **Excel** — Data quality validation
- **MySQL / SQL** — Data analysis and risk engine
- **Power BI / DAX** — Dashboard and reporting

## SQL Analysis

10 business-focused analyses covering:

- Supplier delivery risk
- Inventory stockout risk
- Supplier exposure
- Purchase order fulfillment
- Warehouse inventory risk
- Lead-time and delivery delays
- Monthly delivery trends
- Inventory consumption
- Product–warehouse risk
- Inventory early-warning risk engine

## Inventory Risk Engine

A rule-based **0–100 risk score** based on:

- Current inventory vs. reorder point
- Inventory consumption
- Stock gap

Risk levels:

**Critical → High → Medium → Watch → Low**

The risk score is a business-rule indicator, not a statistical probability of stockout.

## Power BI Dashboard

The dashboard contains four pages:

1. **Executive Overview**
2. **Inventory Risk**
3. **Supplier & Delivery**
4. **Risk Detail**

## Key Results

- 30,000 product–warehouse combinations analyzed
- 4,505 below reorder point
- 14 Critical/High risk items
- 720,115 units consumed
- 13,311 late purchase orders
- ~7.5 days average delay among late deliveries
- ~92% purchase order fulfillment

## Repository Structure

```text
data/

data_quality_audit/

sql/
├── supply_chain_analysis.sql
└── vw_inventory_risk_engine.sql

powerbi/

screenshots/
