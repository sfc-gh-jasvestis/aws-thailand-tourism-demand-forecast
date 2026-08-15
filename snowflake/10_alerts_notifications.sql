-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_thailand_tourism_demand_forecast_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: DEMAND_SURGE_ALERT
CREATE OR REPLACE ALERT APP.DEMAND_SURGE_ALERT
  WAREHOUSE = DEMAND_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Demand surge detected — capacity planning needed'
IF (EXISTS (
  SELECT 1 FROM CURATED.ARRIVAL_TIMESERIES
  WHERE 1=1 -- Condition: FORECAST > 130% of same period last year for any market
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_tourism_demand_forecast_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Tourism Demand Forecasting: Demand surge detected — capacity planning needed',
    'Demand surge detected — capacity planning needed'
  );

ALTER ALERT APP.DEMAND_SURGE_ALERT RESUME;

-- Alert: FORECAST_MISS_ALERT
CREATE OR REPLACE ALERT APP.FORECAST_MISS_ALERT
  WAREHOUSE = DEMAND_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Forecast accuracy degrading — model review needed'
IF (EXISTS (
  SELECT 1 FROM CURATED.ARRIVAL_TIMESERIES
  WHERE 1=1 -- Condition: ABS(FORECAST_ERROR) > 20% for any market-destination pair
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_tourism_demand_forecast_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Tourism Demand Forecasting: Forecast accuracy degrading — model review needed',
    'Forecast accuracy degrading — model review needed'
  );

ALTER ALERT APP.FORECAST_MISS_ALERT RESUME;

