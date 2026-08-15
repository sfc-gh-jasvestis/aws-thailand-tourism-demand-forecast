-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Tourism Demand Forecasting
-- Country: THAILAND | Currency: THB
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- ARRIVAL_HISTORY: 146,000 rows — Daily arrivals by source market and destination (20 markets × 5 destinations × ~1460 days)
-- FLIGHT_SCHEDULES: 25,000 rows — Inbound flight capacity by route and airline
-- VISA_APPLICATIONS: 80,000 rows — Visa application volumes as leading demand indicator
-- SEARCH_TRENDS: 300,000 rows — Google Trends and OTA search data for Thailand destinations
-- EVENT_CALENDAR: 500 rows — Thai festivals, events, and public holidays
-- MACRO_INDICATORS: 960 rows — Source market economic indicators (GDP, exchange rate, CPI)
-- HOTEL_CAPACITY: 2,500 rows — Hotel room supply by destination
-- THAI_TOURISM_POLICY: 20 rows — Visa policy changes, bilateral agreements, promotion campaigns
