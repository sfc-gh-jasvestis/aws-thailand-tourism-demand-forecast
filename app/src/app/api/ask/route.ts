import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  properties: {
    match: /sell-out|sellout|sold out|property|hotel|destination|worst|highest|recall/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, PACE_FLAG_COUNT, SELLOUT_COUNT, RECALL_COUNT, ROUND(FLAG_SELLOUT_PCT, 1) AS FLAG_SELLOUT_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY SELLOUT_COUNT DESC) <= 3
ORDER BY SELLOUT_COUNT DESC, PACE_FLAG_COUNT DESC`,
  },
  types: {
    match: /type|reason|cause|why|flag|driver|root/i,
    sql: `SELECT PACE_FLAG_TYPE, PACE_FLAG_COUNT, SELLOUT_COUNT, RECALL_COUNT, ROUND(FLAG_SELLOUT_PCT, 1) AS FLAG_SELLOUT_PCT
FROM CURATED.PACE_FLAG_SUMMARY ORDER BY SELLOUT_COUNT DESC LIMIT 8`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Flag-free day rate = property-days without a pace flag / property-days. Flag sell-out rate = early sell-outs / pace flags raised. ' +
  'An allotment recall pulls unsold wholesaler or tour operator allotment back to cover a surge. Flight disruption flags are destination-wide and always resolve without an early sell-out. ' +
  'Values are in THB and room nights; properties are fictional hotels in 5 Thai destinations. All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a revenue management analyst at a fictional Thai hotel group. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, properties, types, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.properties.sql),
        executeQuery(INTENTS.types.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(SELLOUT_PROB_7D, 2) AS SELLOUT_PROB_7D, RISK_BAND
FROM ML.SELLOUT_RISK_SCORES ORDER BY SELLOUT_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS PROPERTIES FROM ML.SELLOUT_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topSelloutProperties: properties, paceFlagTypes: types, top5ByRisk: risk, propertiesPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the Director of Revenue Management with 3 prioritised actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
