# Thailand Tourism Demand Forecast

**Thailand - Tourism**
Use case: Booking pace flags, early sell-outs, revenue controls and early sell-out risk

> Room-night demand forecasting for 40 fictional hotel properties of a fictional Thai hotel group, in Bangkok, Phuket, Chiang Mai, Pattaya and Krabi: dynamic tables, a holdout-evaluated early sell-out classifier, a network room-night forecast and pickup forecast error anomaly detection, a Cortex Agent with SOP citations, a live channel booking feed with an alert, and an SPCS app.

## Why Snowflake

- **Dynamic tables** reconcile room nights sold, pace flags, early sell-outs, allotment recalls and pickup review adherence from RAW property data, with checks in `run_core.py`
- **Early sell-out classification** gives a holdout-evaluated next-7-day probability per property
- **Room-night forecast** projects 14 days of network-wide room nights with prediction intervals, for revenue planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live bookings**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.HOTEL_PROPERTIES` (40 rows) |
| Fact table | `RAW.PROPERTY_DAILY` (3,600 property-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `PACE_FLAG_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.SELLOUT_RISK_SCORES`, `ML.SELLOUT_RISK_HOLDOUT_METRICS`, `ML.ROOM_NIGHT_FORECAST`, `ML.FORECAST_ERROR_ANOMALIES` |

Currency: THB. Destinations: Bangkok, Phuket, Chiang Mai, Pattaya, Krabi.
Segments: Upscale hotel, Midscale hotel, Boutique hotel, Serviced apartment, Luxury resort.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Flag-Free Day Rate | 83.86% |
| Pace Flags Raised | 643 |
| Early Sell-outs | 176 |
| Flag Sell-out Rate | 27.4% |
| Allotment Recalls | 82 |
| Room Revenue (THB M) | 1,844 |
| Room Nights Sold | 542,879 |
| Pickup Review Adherence | 76.1% |
| Properties Monitored | 40 |
| Allotment Confirmation Coverage | 58.2% |
| Allotment Confirmations Pending | 23 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily pace flags against early sell-outs, pace flags and early sell-outs by flag type, property table
2. Predictive: holdout metrics, risk bands, 14-day network room-night forecast, pickup forecast error anomalies
3. Controls: pickup review adherence, allotment confirmation coverage and pending confirmations, pickup review adherence against early sell-outs, then generate the action memo
4. Live Bookings: run `CALL APP.SIMULATE_BOOKINGS(20)` (Snowflake only) or `python aws/publish_bookings.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_BOOKINGS_ALERT` and show the alert log and email
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 83.86% of property-days run without a pace flag; the 643 pace flags are where revenue analyst time goes, and more than 1 in 4 of them (27.4%) end in an early sell-out.
- Overbooking risk flags produce the most early sell-outs: 36 early sell-outs from 115 overbooking risk flags. A flight disruption hits every property in a destination at once (Phuket and Krabi) and is always resolved without an early sell-out.
- The risk model is evaluated on a time-based holdout: precision 0.37 and recall 0.26 at 0.5, against a 0.19 base rate. Present it as triage, not a verdict.
- Flight disruption flags are excluded from model training, because they are destination-wide rather than property-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
