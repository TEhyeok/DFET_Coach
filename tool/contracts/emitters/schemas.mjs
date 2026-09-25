// schemas/ emitter (DF-027). Only the listed files are generated; the rest of schemas/ is hand-written
// (JSON Schemas from DF-006), so schemas/ is not a generator-owned directory.
import { lines } from './common.mjs';

// schemas/feature-flags.example.json: the `appConfig/features` document with every key at its contract
// default (all false). Emulator seeds and the AD-07 route start from this shape (V1-05 §4.17).
// JSON cannot carry the GENERATED header, so the file has none (like the Functions json/ copies).
export function renderFeatureFlagsExample({ featureFlags }) {
  const doc = Object.fromEntries(featureFlags.doc.flags.map((f) => [f.key, f.default]));
  return lines([JSON.stringify(doc, null, 2)]);
}

export const schemasEmitters = Object.freeze({
  featureFlagsExample: {
    id: 'schemas.featureFlagsExample',
    path: 'schemas/feature-flags.example.json',
    comment: null,
    uses: ['featureFlags'],
    render: renderFeatureFlagsExample,
  },
});
