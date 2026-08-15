-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Tourism Demand Forecasting
-- ============================================================================
USE DATABASE TOURISM_DEMAND;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.TOURISM_DEMAND_AGENT
  COMMENT = 'Tourism Demand Forecasting AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'TOURISM_DEMAND.APP.TOURISM_DEMAND_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'TOURISM_DEMAND.SEARCH.TOURISM_POLICY_SEARCH', TOOL_DESCRIPTION => 'Search documents for Tourism & Hospitality information')
  )
  SYSTEM_PROMPT = 'You are the Tourism Demand Intelligence Agent for Thailand''s tourism ecosystem, forecasting arrivals from 20 source markets across 5 destinations.';
