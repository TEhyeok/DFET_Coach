import { z } from 'zod';

const kitSchema = z
  .object({
    udi: z.string().max(256).optional(),
    qr: z.string().max(2048).optional(),
    lot: z.string().max(128).optional(),
    expiresAt: z.string().refine(
      (value) => !Number.isNaN(Date.parse(value)),
      '유효기간 형식이 올바르지 않습니다.',
    ).optional(),
  })
  .optional();

export const ingestionEnvelopeSchema = z.object({
  schemaVersion: z.literal('1.0'),
  source: z.enum(['external_api', 'admin_json', 'admin_csv']),
  externalReportId: z.string().min(1).max(160),
  revision: z.number().int().positive(),
  memberRef: z.union([
    z.string().min(1).max(256),
    z.object({
      type: z.enum(['uid', 'externalId']),
      value: z.string().min(1).max(256),
    }),
  ]),
  sampledAt: z.iso.datetime(),
  reportedAt: z.iso.datetime(),
  payload: z.record(z.string(), z.unknown()),
  kit: kitSchema,
  idempotencyKey: z.string().min(8).max(256),
}).refine(
  (value) => Date.parse(value.reportedAt) >= Date.parse(value.sampledAt),
  {
    message: '보고 시각은 채취 시각보다 빠를 수 없습니다.',
    path: ['reportedAt'],
  },
);

export type IngestionEnvelope = z.infer<typeof ingestionEnvelopeSchema>;

export const bloodCodes = [
  'ALT', 'AST', 'TBIL', 'DBIL', 'TP', 'ALB', 'UREA', 'CRE', 'UA',
  'GLU', 'TG', 'CHOL', 'HDL-C',
] as const;
