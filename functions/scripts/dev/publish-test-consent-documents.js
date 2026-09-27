#!/usr/bin/env node
'use strict';

// DF-109 / DEC-22: immutable TEST-ONLY notices for the one-person alpha MVP.
// Default: print a dry-run without initializing Firebase or reading existing data.
// Emulator: --apply --project demo-dfet (FIRESTORE_EMULATOR_HOST required).
// Owner only: --apply --project dfetmanage. Agents must never execute that command.
// These documents and unsigned consent records must be removed before real-member use.

const VERSION = 'mvp-test-1';

function buildDocuments() {
  const byType = {
    required: {
      title: '[테스트 전용] 기본 정보 처리 동의',
      purpose: '가상 테스트 회원의 등록과 동의 흐름 검증',
      items: ['합성 표시명', '성별', '출생연도', '만 14세 확인'],
      refusalNotice: '동의를 거부할 수 있으며, 거부하면 테스트 회원 등록을 계속할 수 없습니다.',
    },
    healthData: {
      title: '[테스트 전용] 건강정보 처리 동의',
      purpose: '합성 건강 기록과 신체조성 입력·조회 흐름 검증',
      items: ['합성 SOAP 기록', '합성 신체조성 수치', '테스트 측정값'],
      refusalNotice: '동의를 거부할 수 있으며, 거부하면 건강 기록을 작성할 수 없습니다.',
    },
    bodyImaging: {
      title: '[테스트 전용] 신체 이미지 처리 동의',
      purpose: '허용된 테스트 이미지와 자세 평가 흐름 검증',
      items: ['합성 또는 사용 권한이 확인된 테스트 이미지', '테스트 자세 정보'],
      refusalNotice: '동의를 거부할 수 있으며, 거부하면 체형 사진을 촬영·저장할 수 없습니다.',
    },
  };
  return Object.fromEntries(Object.entries(byType).map(([consentType, fields]) => [
    `${consentType}--${VERSION}`, {
      consentType, version: VERSION, ...fields,
      retention: '게시일부터 30일 이내, 실회원 투입 전 삭제',
      recipient: null, privacyPolicyVersion: 'mvp-test-only', status: 'published', schemaVersion: 1,
    },
  ]));
}

function parseArgs(argv) {
  const options = {apply: false, project: null};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--apply') options.apply = true;
    else if (argv[i] === '--project' && argv[i + 1] && !argv[i + 1].startsWith('--')) {
      options.project = argv[++i];
    } else throw new Error('usage: publish-test-consent-documents.js [--apply --project <project-id>]');
  }
  if (options.apply && !options.project) throw new Error('--apply requires an explicit --project');
  return options;
}

async function publish(db) {
  const documents = buildDocuments();
  return db.runTransaction(async tx => {
    const existing = await tx.getAll(...Object.keys(documents).map(id => db.doc(`consentDocumentVersions/${id}`)));
    let created = 0;
    for (const snap of existing) {
      if (!snap.exists) continue;
      const {publishedAt, ...body} = snap.data();
      // Published documents are immutable. A content change needs a new VERSION.
      if (!publishedAt || Object.keys(body).length !== Object.keys(documents[snap.id]).length ||
        Object.entries(documents[snap.id]).some(([key, value]) => JSON.stringify(body[key]) !== JSON.stringify(value))) {
        throw new Error('Published test document differs; use a new version instead of overwriting it');
      }
    }
    const {FieldValue} = require('firebase-admin/firestore');
    for (const snap of existing) {
      if (!snap.exists) {
        tx.create(snap.ref, {...documents[snap.id], publishedAt: FieldValue.serverTimestamp()});
        created += 1;
      }
    }
    return {created, unchanged: existing.length - created};
  });
}

async function main(argv = process.argv.slice(2), env = process.env) {
  const options = parseArgs(argv);
  if (!options.apply) {
    console.log(JSON.stringify({dryRun: true, documents: buildDocuments()}, null, 2));
    return;
  }
  const isEmulatorProject = /^demo-[a-z0-9-]+$/.test(options.project) || options.project === 'dfet-e2e';
  if (isEmulatorProject && !env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator project requires FIRESTORE_EMULATOR_HOST');
  if (!isEmulatorProject && (options.project !== 'dfetmanage' || env.FIRESTORE_EMULATOR_HOST)) {
    throw new Error('Use an emulator project, or the owner-only explicit production project');
  }
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: options.project}, 'publish-test-consent-documents');
  try {
    console.log(JSON.stringify(await publish(getFirestore(app))));
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch(() => {
    console.error('Test consent document publication failed; check arguments, environment, and immutable versions.');
    process.exitCode = 1;
  });
}

module.exports = {buildDocuments, parseArgs, publish, main};
