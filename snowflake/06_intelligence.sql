-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-bookings alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_BOOKINGS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic pace-flag knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.PACE_DOCS AS
WITH types AS (
  SELECT DISTINCT r.PACE_FLAG_TYPE, a.CATEGORY
  FROM RAW.PROPERTY_DAILY r JOIN RAW.HOTEL_PROPERTIES a ON a.ID = r.ENTITY_ID
  WHERE r.SELLOUT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, PACE_FLAG_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  PACE_FLAG_TYPE,
  CATEGORY || ' - ' || PACE_FLAG_TYPE || ' pace flag handling' AS TITLE,
  'Synthetic demo SOP. Property segment: ' || CATEGORY || '. Pace flag type: ' || PACE_FLAG_TYPE || '. '
  || 'Step 1: open a revenue case, link the property and pause discounted rate plans for the affected stay dates until the case is triaged. '
  || 'Step 2: ' || CASE
       WHEN PACE_FLAG_TYPE = 'Group block surge' THEN 'confirm the group rooming list and cut-off date, release unconfirmed block rooms back to general sale, and raise the transient rate for the shoulder nights.'
       WHEN PACE_FLAG_TYPE = 'Event surge' THEN 'check the destination event calendar, close the lowest rate tiers for the event nights, and apply a minimum length of stay where the forecast supports it.'
       WHEN PACE_FLAG_TYPE = 'Pickup above pace' THEN 'compare the last 4 weeks of pickup with the forecast, lift the baseline in the next pickup review, and record the bias for the weekly revenue meeting.'
       WHEN PACE_FLAG_TYPE = 'OTA rate parity gap' THEN 'compare the public rate on each online travel agency with the direct channel, correct the loaded rate, and log the gap with the distribution team.'
       WHEN PACE_FLAG_TYPE = 'Overbooking risk' THEN 'recheck the overbooking allowance against recent no-show and cancellation rates, and reduce it for the flagged nights.'
       WHEN PACE_FLAG_TYPE = 'Late allotment release' THEN 'ask the tour operator or wholesaler to confirm or release its allotment before the release date, and recall unsold rooms in line with the contract.'
       WHEN PACE_FLAG_TYPE = 'Long-stay displacement' THEN 'compare long-stay contract rates with the forecast transient rate, and cap new long-stay check-ins over the peak nights.'
       ELSE 'review the flag against the property history and escalate if unexplained.'
     END
  || ' Step 3: if the pickup forecast error for the property exceeds 25% or the rate response time exceeds 72 hours after triage, keep the case open and request a revenue review. '
  || 'Step 4: record the resolution; if the property sold out early or needed an allotment recall, notify the reservations team and log it for the weekly revenue report.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PACE_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, PACE_FLAG_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, PACE_FLAG_TYPE, CONTENT FROM SEARCH.PACE_DOCS);

-- ---------- Pickup forecast error anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.FORECAST_ERROR_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, FORECAST_ERROR_PCT::FLOAT AS FORECAST_ERROR
FROM RAW.PROPERTY_DAILY;
CREATE OR REPLACE VIEW ML.FORECAST_ERROR_TRAIN AS
SELECT * FROM ML.FORECAST_ERROR_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.FORECAST_ERROR_SERIES);
CREATE OR REPLACE VIEW ML.FORECAST_ERROR_DETECT AS
SELECT * FROM ML.FORECAST_ERROR_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.FORECAST_ERROR_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.FORECAST_ERROR_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.FORECAST_ERROR_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'FORECAST_ERROR',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.FORECAST_ERROR_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS FORECAST_ERROR, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.FORECAST_ERROR_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.FORECAST_ERROR_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'FORECAST_ERROR'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.TOURISM_DEMAND_ANALYTICS
  TABLES (
    hotels AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'properties', 'hotels')
      COMMENT = 'One row per hotel property (destination and segment), 90-day totals',
    risk AS ML.SELLOUT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day early sell-out probability per property',
    flags AS CURATED.PACE_FLAG_SUMMARY PRIMARY KEY (PACE_FLAG_TYPE)
      COMMENT = 'Pace flags, early sell-outs and allotment recalls by pace flag type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_property AS risk (ENTITY_ID) REFERENCES hotels)
  FACTS (
    hotels.flags_f AS PACE_FLAG_COUNT,
    hotels.sellouts_f AS SELLOUT_COUNT,
    hotels.recalls_f AS RECALL_COUNT,
    hotels.nights_f AS ROOM_NIGHTS,
    hotels.free_day_pct_f AS FLAG_FREE_DAY_PCT,
    hotels.revenue_f AS ROOM_REVENUE_THB,
    hotels.review_due_f AS PICKUP_REVIEW_DUE,
    hotels.review_done_f AS PICKUP_REVIEW_DONE,
    risk.sellout_prob_f AS SELLOUT_PROB_7D,
    flags.type_flags_f AS PACE_FLAG_COUNT,
    flags.type_sellouts_f AS SELLOUT_COUNT,
    flags.type_recalls_f AS RECALL_COUNT,
    flags.type_revenue_f AS EXPOSED_REVENUE_THB,
    daily.day_flags_f AS PACE_FLAG_COUNT,
    daily.day_sellouts_f AS SELLOUT_COUNT,
    daily.day_revenue_f AS ROOM_REVENUE_THB
  )
  DIMENSIONS (
    hotels.property_id AS ENTITY_ID WITH SYNONYMS = ('property', 'hotel', 'entity'),
    hotels.property_name AS ENTITY_NAME,
    hotels.destination AS REGION WITH SYNONYMS = ('destination', 'city', 'region')
      COMMENT = 'Thai destination where the property is located',
    hotels.segment AS CATEGORY WITH SYNONYMS = ('property segment', 'hotel type'),
    hotels.risk_tier AS RISK_TIER COMMENT = 'Demand volatility tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    flags.pace_flag_type AS PACE_FLAG_TYPE WITH SYNONYMS = ('flag type', 'pace driver', 'root cause'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    hotels.property_count AS COUNT(hotels.property_id) WITH SYNONYMS = ('number of properties', 'number of entities', 'how many hotels'),
    hotels.flag_free_day_rate AS AVG(hotels.free_day_pct_f)
      WITH SYNONYMS = ('flag-free rate', 'clean day rate')
      COMMENT = 'Property-days without a pace flag / property-days (every property has 90 days, so the average is exact)',
    hotels.flag_to_sellout_pct AS 100 * SUM(hotels.sellouts_f) / NULLIF(SUM(hotels.flags_f), 0)
      COMMENT = 'Early sell-outs / pace flags raised',
    hotels.pace_flags_raised AS SUM(hotels.flags_f) WITH SYNONYMS = ('pace flags', 'flags'),
    hotels.total_sellouts AS SUM(hotels.sellouts_f) WITH SYNONYMS = ('early sell-outs', 'sold out nights'),
    hotels.allotment_recalls AS SUM(hotels.recalls_f) WITH SYNONYMS = ('recalls', 'allotment pulled back'),
    hotels.room_nights_sold AS SUM(hotels.nights_f) WITH SYNONYMS = ('room nights', 'demand', 'occupied rooms'),
    hotels.total_room_revenue_thb AS SUM(hotels.revenue_f) WITH SYNONYMS = ('room revenue', 'revenue in THB'),
    hotels.pickup_review_adherence_pct AS 100 * SUM(hotels.review_done_f) / NULLIF(SUM(hotels.review_due_f), 0)
      COMMENT = 'Pickup reviews completed / pickup reviews due',
    risk.avg_sellout_prob AS AVG(risk.sellout_prob_f),
    flags.type_flags AS SUM(flags.type_flags_f),
    flags.type_sellouts AS SUM(flags.type_sellouts_f),
    flags.type_recalls AS SUM(flags.type_recalls_f),
    flags.type_sellout_share_pct AS 100 * SUM(flags.type_sellouts_f) / NULLIF(SUM(flags.type_flags_f), 0),
    daily.daily_flags AS SUM(daily.day_flags_f),
    daily.daily_sellouts AS SUM(daily.day_sellouts_f),
    daily.daily_revenue_thb AS SUM(daily.day_revenue_f)
  )
  COMMENT = 'Synthetic Thailand tourism room-night demand analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.TOURISM_DEMAND_AGENT
  COMMENT = 'Room-night demand assistant over a synthetic Thai hotel portfolio'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give property IDs and numbers with units (room nights, THB, %)."
  orchestration: "Use demand_analyst for room nights sold, room revenue, pace flags, early sell-outs, allotment recalls, flag-free day rate, pickup review adherence, properties, destinations, segments, pace flag types and sell-out risk. Use sop_search for pace flag handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: demand_analyst
      description: "Room nights sold, room revenue in THB, pace flags, early sell-outs, allotment recalls, flag-free day rate, pickup review adherence, pace flag types and early sell-out risk scores by property, Thai destination and segment"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic pace flag handling SOPs by property segment and pace flag type"
tool_resources:
  demand_analyst:
    semantic_view: __DEMO_DB__.APP.TOURISM_DEMAND_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.PACE_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-bookings alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), PROPERTY_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, BOOKING_VALUE_THB FLOAT, STAY_LEAD_DAYS FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION TH_TOURISM_DEMAND_FORECAST_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (PROPERTY_ID, EVENT_TS, BOOKING_VALUE_THB, STAY_LEAD_DAYS, SOP_HINT)
    SELECT p.PROPERTY_ID, p.EVENT_TS, p.BOOKING_VALUE_THB, p.STAY_LEAD_DAYS,
           'Check ' || r.CATEGORY || ' pace flag SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_BOOKINGS p
    JOIN RAW.HOTEL_PROPERTIES r ON r.ID = p.PROPERTY_ID
    LEFT JOIN ML.SELLOUT_RISK_SCORES s ON s.ENTITY_ID = p.PROPERTY_ID
    WHERE p.STATUS = 'PACE_FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PROPERTY_ID = p.PROPERTY_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('TH_TOURISM_DEMAND_FORECAST_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Booking pace flag alert',
      'New live booking pace flags logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_BOOKINGS_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_BOOKINGS p
    WHERE p.STATUS = 'PACE_FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PROPERTY_ID = p.PROPERTY_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.PACE_FLAG_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.SELLOUT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.SELLOUT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.SELLOUT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PROPERTY_AGE_YEARS', PROPERTY_AGE_YEARS,
             'FORECAST_ERROR_PCT', FORECAST_ERROR_PCT, 'RATE_RESPONSE_HRS', RATE_RESPONSE_HRS,
             'FORECAST_ERROR_7D', FORECAST_ERROR_7D, 'SELLOUT_30D', SELLOUT_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:SELLOUT::FLOAT, 4) AS SELLOUT_PROB_7D,
         CASE WHEN PRED:probability:SELLOUT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:SELLOUT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
