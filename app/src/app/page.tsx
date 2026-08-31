'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';
import { GeoMap } from '@/components/GeoMap';
import { ArchitectureDiagram } from '@/components/ArchitectureDiagram';

interface DemoNarrative {
  title: string;
  duration: string;
  thesis: string;
  tabs: any[];
}

export default function HomePage() {
  const [narrative, setNarrative] = useState<DemoNarrative | null>(null);
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    fetch('/demo_narrative.json')
      .then((r) => r.json())
      .then(setNarrative)
      .catch(() => {});
    fetch('/api/data')
      .then((r) => r.json())
      .then(setData)
      .catch(() => {});
  }, []);

  const title = narrative?.title || 'SEA AWS Demo';

  const executiveCockpit = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Arrivals Forecast (30d)" value="3.2M" status="neutral" />
        <KPICard title="Revenue Forecast" value="฿148B" status="neutral" />
        <KPICard title="Forecast Accuracy" value="94.1%" status="neutral" />
        <KPICard title="Markets Tracked" value="42" status="neutral" />
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="lg:col-span-1">
          <GeoMap
            country="thailand"
            markers={[{"label": "Bangkok", "value": "1.2M arrivals/mo", "color": "blue", "size": "lg"}, {"label": "Phuket", "value": "840K arrivals", "color": "blue", "size": "lg"}, {"label": "Chiang Mai", "value": "420K arrivals", "color": "green", "size": "md"}, {"label": "Samui", "value": "Occ: 84%", "color": "green", "size": "md"}, {"label": "Pattaya", "value": "Occ: 72%", "color": "amber", "size": "sm"}]}
            routes={[]}
            title="Geographic Overview"
            height={400}
          />
        </div>
        <div className="lg:col-span-1 grid grid-cols-1 gap-4">
      <div className="grid grid-cols-1 gap-4 grid-cols-1">
        <Chart
          data={data?.timeseries || [{ period: 'Loading', value: 0 }]}
          type="line"
          xKey="period"
          yKeys={[{ key: 'value', name: 'Arrivals (K)' }]}
          title="Tourist Arrivals (Monthly)"
        />
        <Chart
          data={data?.categories || [{ category: 'Loading', count: 0 }]}
          type="bar"
          xKey="category"
          yKeys={[{ key: 'count', name: '฿B' }]}
          title="Revenue by Source Market"
        />
      </div>
        </div>
      </div>
      <DataTable
        columns={[
          { key: 'id', header: 'Rank' },
          { key: 'name', header: 'Market' },
          { key: 'status', header: 'Trend' },
          { key: 'value', header: 'Arrivals (K)' },
        ]}
        data={data?.entities || []}
        title="Top Source Markets"
      />
    </div>
  );

  const domainTab1 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="China Recovery" value="78%" />
        <KPICard title="Avg Spend/Tourist" value="฿47K" />
        <KPICard title="Visa-Free Impact" value="+22%" />
      </div>
      <Chart
        data={data?.detail || [{ x: 'Loading', y: 0 }]}
        type="area"
        xKey="x"
        yKeys={[{ key: 'y', name: 'Index' }]}
        title="Demand Signal by Market"
        height={400}
      />
    </div>
  );

  const domainTab2 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart
          data={data?.breakdown || [{ label: 'A', value: 30 }, { label: 'B', value: 70 }]}
          type="pie"
          xKey="label"
          yKeys={[{ key: 'value', name: 'Occupancy %' }]}
          title="Hotel Occupancy Forecast"
        />
        <ActionMemo
          persona={{ name: 'Thanakorn Wanglee', role: 'TAT Deputy Governor' }}
          context={{}}
          onGenerate={async () => ({
            subject: 'Action Required',
            body: 'AI-generated recommendation based on current data patterns and predicted trends.',
            urgency: 'HIGH',
            actions: ['Alert Phuket: Chinese groups +40% next month', 'Recommend flight capacity increase BKK-Mumbai', 'Brief immigration on Songkran surge'],
          })}
        />
      </div>
    </div>
  );

  const askAiTab = (
    <div className="h-[600px]">
      <AskAI
        title="Ask AI"
        sampleQuestions={[
          'What is the 90-day forecast for Chinese arrivals?',
          'Which destinations are under-capacity for high season?',
          'Show flight capacity vs arrivals correlation',
        ]}
        mode="sql"
        onSubmit={async (question, mode) => {
          return {
            answer: `[Demo Mode] Response to: "${question}" (${mode} mode). Connect to Snowflake for live data.`,
            sql: mode === 'sql' ? 'SELECT * FROM CURATED.SUMMARY LIMIT 10;' : undefined,
          };
        }}
      />
    </div>
  );

  const architectureTab = (
    <ArchitectureDiagram
      snowflakeFeatures={['Dynamic Tables (5-min refresh)', 'ML Functions (Forecast + Anomaly)', 'Cortex Search + Agent', 'Semantic View + Intelligence', 'Alerts + Notifications']}
      awsServices={[{ name: 'Amazon S3', role: 'Strategy Docs' }, { name: 'Amazon S3 + Kinesis', role: 'Integration' }, { name: 'Amazon SNS', role: 'Integration' }, { name: 'Amazon QuickSight + Q', role: 'Integration' }]}
    />
  );

  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '📊', content: executiveCockpit },
    { id: 'domain-1', label: 'Market Intelligence', icon: '📈', content: domainTab1 },
    { id: 'domain-2', label: 'Capacity Planning', icon: '⚡', content: domainTab2 },
    { id: 'ask-ai', label: 'Ask AI', icon: '🤖', content: askAiTab },
    { id: 'architecture', label: 'Architecture & Data', icon: '🏗️', content: architectureTab },
  ];

  return (
    <AppLayout
      title={title}
      tabs={tabs}
      narrative={narrative}
    />
  );
}
