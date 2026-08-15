-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.TOURISM_DEMAND_ANALYTICS
  COMMENT = 'Tourism demand forecasting, arrival trends, and capacity planning'
AS
  TABLES (
    CURATED.ARRIVAL_TIMESERIES AS arrival_timeseries,CURATED.DEMAND_LEADING_INDICATORS AS demand_leading_indicators,CURATED.FORECAST_VS_ACTUAL AS forecast_vs_actual,CURATED.CAPACITY_UTILIZATION AS capacity_utilization
  );
