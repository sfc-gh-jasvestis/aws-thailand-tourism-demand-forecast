'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface DemandData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; flags: number | null; sellouts: number | null }[];
  categories: { category: string; flags: number | null; sellouts: number | null }[];
  entities: Record<string, string | number | null>[];
  reviewRisk: { name: string; compliance: number; sellouts: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; flags: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<DemandData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Flag-Free Day Rate', 'Pace Flags Raised', 'Early Sell-outs', 'Room Revenue (THB M)'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Flag-free day rate = property-days without a booking pace flag / property-days. Flag sell-out rate = pace flags that end in an early sell-out / pace flags raised. Room revenue is the THB value of all room nights in the snapshot.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'flags', name: 'Pace flags raised' }, { key: 'sellouts', name: 'Early sell-outs' }]} title="Daily Pace Flags" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'flags', name: 'Pace flags' }, { key: 'sellouts', name: 'Early sell-outs' }]} title="Pace Flags and Early Sell-outs by Flag Type" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Property' }, { key: 'region', header: 'Destination' }, { key: 'category', header: 'Segment' },
        { key: 'tier', header: 'Volatility tier' }, { key: 'nights', header: 'Room nights' }, { key: 'flags', header: 'Pace flags' },
        { key: 'sellouts', header: 'Early sell-outs' }, { key: 'recalls', header: 'Allotment recalls' }, { key: 'value', header: 'Room revenue (THB M)' },
      ]} data={data?.entities ?? []} title="Property observations, 90 days (fictional hotels in 5 Thai destinations)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day early sell-out risk and network room-night forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a property sells out early in the next 7 days,
        from the pickup forecast error, rate response time, recent early sell-outs, demand volatility tier, property age and segment.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} property-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Property' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(early sell-out in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Early sell-out risk by property" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Network-wide room-night forecast, next 14 days (room nights per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Property' }, { key: 'date', header: 'Date' }, { key: 'forecastError', header: 'Pickup forecast error (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Pickup forecast error anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live bookings: Amazon Data Firehose to S3 to Snowpipe' : 'Live bookings: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated channel booking events are sent to the Firehose stream th-tourism-demand-forecast-bookings (aws/publish_bookings.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_BOOKINGS.'
          : 'CALL APP.SIMULATE_BOOKINGS(n) inserts simulated channel booking events directly into RAW.LIVE_BOOKINGS (or resume APP.TASK_SIMULATE_BOOKINGS for a feed every minute). This simulates a channel booking feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_BOOKINGS_ALERT logs PACE_FLAG events and emails the on-call revenue analyst.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Booking events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="PACE_FLAG events" value={String(data?.liveSummary?.flags ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Property' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Booking value (THB)' },
        { key: 'leadDays', header: 'Stay lead time (days)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 booking events" />
      <DataTable columns={[
        { key: 'id', header: 'Property' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'amount', header: 'Booking value (THB)' },
        { key: 'leadDays', header: 'Stay lead time (days)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const controls = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Pickup Review Adherence" value={kpiVal('Pickup Review Adherence')} />
        <KPICard title="Allotment Confirmation Coverage" value={kpiVal('Allotment Confirmation Coverage')} />
        <KPICard title="Allotment Confirmations Pending" value={kpiVal('Allotment Confirmations Pending')} />
      </div>
      <Chart data={data?.reviewRisk ?? []} type="scatter" xKey="compliance" xName="Pickup review adherence"
        yKeys={[{ key: 'sellouts', name: 'Early sell-outs' }]} yDomain={[0, 'auto']}
        title="Pickup review adherence (%) vs early sell-outs by property" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that pickup reviews prevented early sell-outs.</p>
      <ActionMemo persona={{ name: 'Siriporn Wattanakul', role: 'Director of Revenue Management (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft revenue actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, property, pace-flag-type and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.TOURISM_DEMAND_AGENT. It uses Cortex Analyst over the semantic view APP.TOURISM_DEMAND_ANALYTICS for metrics, and Cortex Search over synthetic pace flag handling SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the room-night demand agent" mode="advisor" sampleQuestions={['Which 3 properties have the most early sell-outs?', 'Which properties are high risk this week and what SOP applies?', 'What is the early sell-out share by pace flag type?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: 40 synthetic hotel properties in 5 Thai destinations and 5 property segments, daily property observations and allotment contract confirmations. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION early sell-out risk model evaluated on a time-based holdout, plus a 14-day network room-night FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags pickup forecast error outliers per property over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_BOOKINGS, with a Snowflake alert and email on PACE_FLAG events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily pace flags, early sell-outs by property, early sell-out risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_BOOKINGS inserts simulated channel booking events into RAW.LIVE_BOOKINGS, with a Snowflake alert and email on PACE_FLAG events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'controls', label: 'Controls', icon: '', content: controls },
    { id: 'live', label: 'Live Bookings', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Thai hotel group. On-demand snapshots are not live hotel operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No property observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Thailand Tourism Demand Forecast" tabs={tabs} />;
}
