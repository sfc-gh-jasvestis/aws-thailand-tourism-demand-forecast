-- Synthetic property-day room-night demand observations for a fictional Thai
-- hospitality group. A property is one fictional hotel in one Thai destination.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-property sell-out propensity, pickup drift between weekly
-- pickup reviews, missed pickup reviews, segment-weighted pace flag types,
-- pace flags resolved without an early sell-out, and two flight disruptions.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.HOTEL_PROPERTIES AS
WITH properties AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS PROPERTY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT PROPERTY_INDEX,
         MOD(ABS(HASH(PROPERTY_INDEX, 'thtdf-opened')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(PROPERTY_INDEX, 'thtdf-soldout')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(PROPERTY_INDEX, 'thtdf-pickup-cycle')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(PROPERTY_INDEX, 'thtdf-rm-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(PROPERTY_INDEX, 'thtdf-volatility')), 1000000) / 1e6 AS U_TIER
  FROM properties
)
SELECT 'HTL-' || LPAD(PROPERTY_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic property ' || LPAD(PROPERTY_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every destination and segment is present.
       CASE MOD(PROPERTY_INDEX, 5) WHEN 0 THEN 'Bangkok' WHEN 1 THEN 'Phuket'
            WHEN 2 THEN 'Chiang Mai' WHEN 3 THEN 'Pattaya' ELSE 'Krabi' END AS REGION,
       CASE MOD(PROPERTY_INDEX, 8) WHEN 0 THEN 'Upscale hotel' WHEN 1 THEN 'Upscale hotel'
            WHEN 2 THEN 'Midscale hotel' WHEN 3 THEN 'Midscale hotel' WHEN 4 THEN 'Boutique hotel'
            WHEN 5 THEN 'Boutique hotel' WHEN 6 THEN 'Serviced apartment' ELSE 'Luxury resort' END AS CATEGORY,
       PROPERTY_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_AGE * 14.5, 1) AS PROPERTY_AGE_YEARS,
       -- Base daily early sell-out probability 0.5%-2.9%; ~14% of properties
       -- are chronically volatile (x3).
       (0.005 + U_RATE * 0.024) * IFF(U_RATE > 0.86, 3, 1) AS BASE_SELLOUT_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS PICKUP_REVIEW_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS PICKUP_REVIEW_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.PROPERTY_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), destination_events AS (
  -- Two flight disruptions; every property in the destination raises a pace
  -- flag that is resolved once rebooked arrivals land.
  SELECT * FROM VALUES (27, 'Phuket'), (63, 'Krabi') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.PROPERTY_INDEX, s.CATEGORY, s.REGION, s.PROPERTY_AGE_YEARS,
         s.BASE_SELLOUT_RATE, s.PICKUP_REVIEW_INTERVAL_DAYS, s.PICKUP_REVIEW_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.PROPERTY_INDEX * 3, s.PICKUP_REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-fullhouse')), 1000000) / 1e6 AS U_SELLOUT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-paceflag')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-absorbed')), 1000000) / 1e6 AS U_RESOLVE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-driver')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-reviewed')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-roomnights')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-adr')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thtdf-wholesale')), 1000000) / 1e6 AS U_RECALL,
         e.REGION IS NOT NULL AS DEST_EVENT
  FROM RAW.HOTEL_PROPERTIES s CROSS JOIN days d
  LEFT JOIN destination_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), review AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS PICKUP_REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < PICKUP_REVIEW_COMPLETION_PROB, 1, 0) AS PICKUP_REVIEW_DONE,
         -- Pickup drift rises between pickup reviews; weak review adherence
         -- carries it over.
         DAYS_SINCE_REVIEW / PICKUP_REVIEW_INTERVAL_DAYS + (1 - PICKUP_REVIEW_COMPLETION_PROB) AS DRIFT
  FROM base
), surges AS (
  SELECT *,
         CASE WHEN U_SELLOUT < LEAST(0.5, BASE_SELLOUT_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROPERTY_AGE_YEARS))) / 4 THEN 2
              WHEN U_SELLOUT < LEAST(0.5, BASE_SELLOUT_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROPERTY_AGE_YEARS))) THEN 1
              ELSE 0 END AS SELLOUT_RISK_COUNT
  FROM review
), flags AS (
  SELECT *,
         -- About 85% of surges raise a pace flag and end in an early sell-out;
         -- the rest are absorbed by recalling wholesaler allotment without a flag.
         IFF(DEST_EVENT, 0, IFF(U_DETECT < 0.85, SELLOUT_RISK_COUNT, 0)) AS SELLOUT_COUNT,
         -- Pace flags resolved without a sell-out: higher where inventory is more flexible.
         IFF(DEST_EVENT, 1, IFF(U_RESOLVE < CASE CATEGORY WHEN 'Serviced apartment' THEN 0.19
                                                         WHEN 'Midscale hotel' THEN 0.11
                                                         WHEN 'Upscale hotel' THEN 0.15 ELSE 0.09 END, 1, 0)) AS RESOLVED_COUNT
  FROM surges
), measured AS (
  SELECT *,
         SELLOUT_COUNT + RESOLVED_COUNT AS PACE_FLAG_COUNT,
         ROUND(CASE CATEGORY WHEN 'Upscale hotel' THEN 210 WHEN 'Midscale hotel' THEN 260
                             WHEN 'Boutique hotel' THEN 38 WHEN 'Serviced apartment' THEN 95 ELSE 70 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.5 * SELLOUT_RISK_COUNT)) AS ROOM_NIGHTS,
         CASE CATEGORY WHEN 'Upscale hotel' THEN 4200 WHEN 'Midscale hotel' THEN 1850
                       WHEN 'Boutique hotel' THEN 3300 WHEN 'Serviced apartment' THEN 2100 ELSE 11500 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_DAILY_RATE_THB
  FROM flags
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       ROOM_NIGHTS,
       ROUND(ROOM_NIGHTS * AVG_DAILY_RATE_THB, 0) AS ROOM_REVENUE_THB,
       PACE_FLAG_COUNT, SELLOUT_COUNT,
       IFF(SELLOUT_COUNT > 0 AND U_RECALL < 0.55, 1, 0) AS ALLOTMENT_RECALL,
       CASE WHEN PACE_FLAG_COUNT = 0 THEN 'None'
            WHEN DEST_EVENT THEN 'Flight disruption'
            WHEN CATEGORY = 'Upscale hotel' THEN IFF(U_TYPE < 0.5, 'Group block surge', IFF(U_TYPE < 0.8, 'Event surge', 'Pickup above pace'))
            WHEN CATEGORY = 'Midscale hotel' THEN IFF(U_TYPE < 0.45, 'OTA rate parity gap', IFF(U_TYPE < 0.8, 'Overbooking risk', 'Pickup above pace'))
            WHEN CATEGORY = 'Boutique hotel' THEN IFF(U_TYPE < 0.55, 'Overbooking risk', 'Late allotment release')
            WHEN CATEGORY = 'Serviced apartment' THEN IFF(U_TYPE < 0.45, 'Long-stay displacement', IFF(U_TYPE < 0.8, 'Late allotment release', 'Pickup above pace'))
            ELSE IFF(U_TYPE < 0.5, 'Event surge', IFF(U_TYPE < 0.75, 'Overbooking risk', 'OTA rate parity gap')) END AS PACE_FLAG_TYPE,
       PICKUP_REVIEW_DUE, PICKUP_REVIEW_DONE,
       ROUND(4.5 + 8.5 * DRIFT + 11.5 * SELLOUT_RISK_COUNT + U_NOISE * 3.0, 2) AS FORECAST_ERROR_PCT,
       ROUND(26 + 18 * DRIFT + 24 * SELLOUT_RISK_COUNT + U_NOISE * 10, 1) AS RATE_RESPONSE_HRS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Allotment and group contract confirmation coverage per property (snapshot).
CREATE TABLE RAW.ALLOTMENT_CONFIRMATIONS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Upscale hotel' THEN 'MICE group block contract'
                     WHEN 'Midscale hotel' THEN 'OTA allocation confirmation'
                     WHEN 'Boutique hotel' THEN 'Tour operator allotment confirmation'
                     WHEN 'Serviced apartment' THEN 'Corporate long-stay agreement'
                     ELSE 'Wholesaler allotment contract' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'thtdf-contracts-due')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'thtdf-contracts-signed')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'thtdf-contracts-signed')), 5) < 1 + MOD(ABS(HASH(ID, 'thtdf-contracts-due')), 4),
           MOD(ABS(HASH(ID, 'thtdf-contracts-chasing')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.HOTEL_PROPERTIES;
