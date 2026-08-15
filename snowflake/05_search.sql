-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.TOURISM_POLICY_SEARCH
  ON POLICY_TEXT
  ATTRIBUTES POLICY_TYPE, SOURCE_MARKET, EFFECTIVE_DATE
  WAREHOUSE = DEMAND_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.THAI_TOURISM_POLICY
);
