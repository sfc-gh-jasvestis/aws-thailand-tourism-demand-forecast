-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_REFRESH_FORECASTS
  WAREHOUSE = DEMAND_WH
  SCHEDULE = 'USING CRON 0 4 * * * UTC'
  COMMENT = 'Refresh 90-day demand forecasts for all market-destination pairs'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_UPDATE_INDICATORS
  WAREHOUSE = DEMAND_WH
  AFTER APP.TASK_REFRESH_FORECASTS
  COMMENT = 'Update leading indicator composite scores'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_BRIEFS
  WAREHOUSE = DEMAND_WH
  AFTER APP.TASK_UPDATE_INDICATORS
  COMMENT = 'Generate market intelligence briefs via Cortex Complete'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_GENERATE_BRIEFS RESUME;
ALTER TASK APP.TASK_UPDATE_INDICATORS RESUME;
ALTER TASK APP.TASK_REFRESH_FORECASTS RESUME;
