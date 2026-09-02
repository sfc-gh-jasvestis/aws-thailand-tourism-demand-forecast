# Tourism Demand Forecasting

**Thailand - Tourism & Hospitality**
Use case: Demand Forecasting & Planning

> National tourism demand forecasting by source market — ML.FORECAST predicts arrivals from 20 source markets, enabling capacity planning, marketing spend allocation, and workforce scheduling across Thailand's tourism ecosystem.

## Why Snowflake

Snowflake forecasts tourist arrivals by source market 90 days ahead, detects demand anomalies, and powers Snowflake Intelligence for tourism planning — replacing disconnected forecasting tools with unified ML-native analytics

- **ML.FORECAST for 100 market-destination pairs** - Only demo forecasting tourism demand at market × destination granularity with confidence bands
- **Composite leading indicator (flights + visa + search)** - Multi-signal early warning system predicting demand 60-90 days ahead
- **Snowflake Intelligence for tourism planning** - Natural language interface for strategic demand questions
- **Thai tourism ecosystem context** - 20 source markets × 5 destinations with realistic seasonal and policy-driven patterns
- **Visa policy impact analysis** - AI extracts and quantifies impact of policy changes on demand forecasts
- **Forecast accuracy monitoring** - Automated detection of forecast degradation with model retrain triggers

## What is deployed

| | |
|---|---|
| Database | `THAILAND_TOURISM_DEMAND_FORECAST` |
| Service | `THAILAND_TOURISM_DEMAND_FORECAST_APP` |
| Compute pool | `SEA_DEMOS_THAILAND_POOL` |
| Dimension table | `RAW.THAI_TOURISM_POLICY` (20 rows) |
| Fact table | `RAW.SEARCH_TRENDS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | THB (฿) |

Regions in play: Bangkok, Chonburi, Rayong, Chiang Mai, Songkhla
Segments: Leisure FIT, Group Tour, MICE, Long Stay

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh THAILAND_TOURISM_DEMAND_FORECAST
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Arrivals Forecast (30d) | `3.2M` | average per event |
| Revenue Forecast | `฿148B` | average per event |
| Forecast Accuracy | `94.1%` | average per event |
| Markets Tracked | `42` | total across Thai Tourism Policy |
| China Recovery | `78%` | average per event |
| Avg Spend/Tourist | `฿47K` | average per event |
| Visa-Free Impact | `+22%` | average per event |


## Demo flow

1. Executive Cockpit
2. Source Market Forecasts
3. Leading Indicators
4. Ask AI
5. Architecture & Data

## Talking points

- **35M arrivals** - forecast for Thailand this year (12% YoY growth)
- **100 forecasts** - market-destination pairs updated daily (ML.FORECAST)
- **67% recovery** - Chinese market vs 2019 baseline
- **140% of 2019** - Indian market exceeding pre-COVID levels
- **60-90 days** - leading indicator early warning window
- **95% utilization** - Phuket peak season hotel capacity forecast

## Business impact

- Thailand tourism contributes ฿2.4 trillion to GDP (18% of national economy) supporting 8M jobs (NESDC Thailand)
- ML-powered demand forecasting improves accuracy by 20-30% vs traditional time-series methods (McKinsey Travel)
- Thailand's visa-free policy for Chinese tourists increased arrivals by 45% within 3 months (TAT Thailand)
- Accurate demand forecasting enables 10-15% better capacity utilization and revenue capture (WTTC)

---
Generated from `generator/demo_specs/aws-thailand-tourism-demand-forecast.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-thailand-tourism-demand-forecast` instead.
