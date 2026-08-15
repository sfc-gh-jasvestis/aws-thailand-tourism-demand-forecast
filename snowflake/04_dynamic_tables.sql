-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA CURATED;

-- ARRIVAL_TIMESERIES: Cleaned daily arrival timeseries by market × destination for ML.FORECAST
-- Source: ARRIVAL_HISTORY
CREATE OR REPLACE DYNAMIC TABLE CURATED.ARRIVAL_TIMESERIES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = DEMAND_WH
AS
SELECT * FROM RAW.ARRIVAL_HISTORY;
-- TODO: Replace with actual join/aggregation logic per demo

-- DEMAND_LEADING_INDICATORS: Composite leading indicator index (flights + visa + search)
-- Source: FLIGHT_SCHEDULES, VISA_APPLICATIONS, SEARCH_TRENDS
CREATE OR REPLACE DYNAMIC TABLE CURATED.DEMAND_LEADING_INDICATORS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = DEMAND_WH
AS
SELECT * FROM RAW.FLIGHT_SCHEDULES;
-- TODO: Replace with actual join/aggregation logic per demo

-- FORECAST_VS_ACTUAL: Forecast accuracy tracking by market and destination
-- Source: ARRIVAL_HISTORY
CREATE OR REPLACE DYNAMIC TABLE CURATED.FORECAST_VS_ACTUAL
  TARGET_LAG = '5 minutes'
  WAREHOUSE = DEMAND_WH
AS
SELECT * FROM RAW.ARRIVAL_HISTORY;
-- TODO: Replace with actual join/aggregation logic per demo

-- CAPACITY_UTILIZATION: Demand vs supply gap by destination
-- Source: ARRIVAL_HISTORY, HOTEL_CAPACITY
CREATE OR REPLACE DYNAMIC TABLE CURATED.CAPACITY_UTILIZATION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = DEMAND_WH
AS
SELECT * FROM RAW.ARRIVAL_HISTORY;
-- TODO: Replace with actual join/aggregation logic per demo

