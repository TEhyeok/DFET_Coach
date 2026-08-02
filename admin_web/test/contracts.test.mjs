import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const { validateEnvelope } = require('../../functions/src/clinical/validation.js');
const { verifyHmac } = require('../../functions/src/clinical/ingestion.js');

function bloodEnvelope() {
  return {
    schemaVersion: '1.0',
    source: 'admin_json',
    externalReportId: 'admin-test-001',
    revision: 1,
    memberRef: 'test-member',
    sampledAt: '2026-08-02T10:00:00.000Z',
    reportedAt: '2026-08-02T10:05:00.000Z',
    payload: { biomarkers: [{ code: 'GLU', value: 5.55, unit: 'mmol/L' }] },
    kit: { lot: 'LOT-001' },
    idempotencyKey: 'blood:admin-test-001:1',
  };
}

test('admin envelope matches the Functions blood contract', () => {
  assert.equal(validateEnvelope('blood', bloodEnvelope()).externalReportId, 'admin-test-001');
});

test('admin HMAC format is accepted by the Functions verifier', () => {
  const rawBody = Buffer.from(JSON.stringify(bloodEnvelope()));
  const timestamp = Date.now().toString();
  const secret = 'test-secret';
  const signature = createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody.toString('utf8')}`)
    .digest('hex');
  assert.equal(
    verifyHmac({
      rawBody,
      keyId: 'admin',
      timestamp,
      signature,
      keyMap: { admin: secret },
    }),
    true,
  );
});
