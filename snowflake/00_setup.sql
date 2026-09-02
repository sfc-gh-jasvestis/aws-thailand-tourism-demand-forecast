-- Generated from generator/demo_specs/aws-thailand-tourism-demand-forecast.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-thailand-tourism-demand-forecast
-- This is the schema that is actually deployed for THAILAND_TOURISM_DEMAND_FORECAST.

-- THAILAND_TOURISM_DEMAND_FORECAST  (Tourism Demand Forecasting)
-- generated from generator/demo_specs/aws-thailand-tourism-demand-forecast.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS THAILAND_TOURISM_DEMAND_FORECAST;
CREATE SCHEMA IF NOT EXISTS THAILAND_TOURISM_DEMAND_FORECAST.RAW;
CREATE SCHEMA IF NOT EXISTS THAILAND_TOURISM_DEMAND_FORECAST.CURATED;
CREATE SCHEMA IF NOT EXISTS THAILAND_TOURISM_DEMAND_FORECAST.APP;
USE DATABASE THAILAND_TOURISM_DEMAND_FORECAST;

-- 5 real regions; entity names carry their region so the two always agree
