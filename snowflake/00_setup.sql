-- ============================================================================
-- Tourism Demand Forecasting
-- National tourism demand forecasting by source market — ML.FORECAST predicts arrivals from 20 source markets, enabling capacity planning, marketing spend allocation, and workforce scheduling across Thailand's tourism ecosystem.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS TOURISM_DEMAND;
CREATE WAREHOUSE IF NOT EXISTS DEMAND_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE TOURISM_DEMAND;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE DEMAND_WH;
