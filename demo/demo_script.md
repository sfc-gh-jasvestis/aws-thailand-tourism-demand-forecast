# Demo Script: Tourism Demand Forecasting
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake forecasts tourist arrivals by source market 90 days ahead, detects demand anomalies, and powers Snowflake Intelligence for tourism planning — replacing disconnected forecasting tools with unified ML-native analytics"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Dr. Arunee Treevichit** | Chief Strategy Officer (Tourism Group) | React App (SPCS) | Source market diversification, seasonal demand patterns, macro risks, capacity planning |
| **Thanakorn Petchnoi** | Demand Planning Analyst | Amazon QuickSight | Forecast accuracy, booking lead times, seasonality decomposition, event impact |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 8 tables | ARRIVAL_HISTORY (146000), FLIGHT_SCHEDULES (25000), VISA_APPLICATIONS (80000), SEARCH_TRENDS (300000), EVENT_CALENDAR (500), MACRO_INDICATORS (960), HOTEL_CAPACITY (2500), THAI_TOURISM_POLICY (20) |
| **CURATED** | 4 Dynamic Tables | ARRIVAL_TIMESERIES, DEMAND_LEADING_INDICATORS, FORECAST_VS_ACTUAL, CAPACITY_UTILIZATION |
| **ML** | ML.FORECAST + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY, AI_EXTRACT | Classification + extraction |
| **Search** | Cortex Search | 20 documents indexed |
| **Agent** | TOURISM_DEMAND_AGENT | Semantic View + Search tools |


---

## The Story

Thailand targets 35 million tourists but planning is fragmented — TAT, hotels, airlines, and tour operators each forecast independently. ML.FORECAST unifies 146,000 data points across 100 market-destination pairs, detecting shifts 60-90 days early through leading indicators and enabling coordinated capacity planning.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "Thailand on track for 35 million arrivals this year — 90-day forecast shows 12% growth vs last year."

**Action**: Point at 35M arrival forecast KPI

### [0:45–1:30] SOURCE MARKET FORECASTS

**Show**: Source Market Forecasts tab

> "ML.FORECAST generates 90-day predictions for 100 market-destination pairs."

**Action**: Show forecast charts by top 5 markets

### [1:30–2:15] LEADING INDICATORS

**Show**: Leading Indicators tab

> "Composite leading indicator combines flight capacity, visa applications, and search trends."

**Action**: Show leading indicator dashboard

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Dr. Arunee asks: 'Where should we allocate Q1 marketing budget across markets?'"

**Action**: Type: 'Optimal Q1 marketing budget allocation by market'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Seven Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST for 100 market-destination pairs** — Only demo forecasting tourism demand at market × destination granularity with confidence bands
2. **Composite leading indicator (flights + visa + search)** — Multi-signal early warning system predicting demand 60-90 days ahead
3. **Snowflake Intelligence for tourism planning** — Natural language interface for strategic demand questions
4. **Thai tourism ecosystem context** — 20 source markets × 5 destinations with realistic seasonal and policy-driven patterns
5. **Visa policy impact analysis** — AI extracts and quantifies impact of policy changes on demand forecasts
6. **Forecast accuracy monitoring** — Automated detection of forecast degradation with model retrain triggers


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM TOURISM_DEMAND.RAW.ARRIVAL_HISTORY` → 146000
- [ ] `SELECT COUNT(*) FROM TOURISM_DEMAND.RAW.SEARCH_TRENDS` → 300000
- [ ] `SELECT COUNT(DISTINCT MARKET_DESTINATION) FROM TOURISM_DEMAND.CURATED.ARRIVAL_TIMESERIES` → 100

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM TOURISM_DEMAND.ML.ARRIVAL_FORECAST_RESULTS` → >0
- [ ] `SELECT SUM(CASE WHEN IS_ANOMALY THEN 1 ELSE 0 END) FROM TOURISM_DEMAND.ML.DEMAND_ANOMALY_RESULTS` → >=10

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM TOURISM_DEMAND.AI.MARKET_INTELLIGENCE_BRIEFS` → >=20

