const fs = require('node:fs');
const path = require('node:path');
const {after, before, beforeEach, describe, test} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'dfet-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/member1'), {
        role: 'user', isApproved: false, isPremium: false, careType: 'fitness',
      }),
      setDoc(doc(db, 'users/member2'), {
        role: 'user', isApproved: false, isPremium: false, careType: 'fitness',
      }),
      setDoc(doc(db, 'trainers/trainer1'), {memberIds: ['member1']}),
      setDoc(doc(db, 'trainers/trainer2'), {memberIds: []}),
      setDoc(doc(db, 'gutReports/gut1'), {userId: 'member1'}),
      setDoc(doc(db, 'gutReportExperts/gut1'), {userId: 'member1'}),
      setDoc(doc(db, 'bloodReports/blood1'), {userId: 'member1'}),
      setDoc(doc(db, 'bloodReportExperts/blood1'), {userId: 'member1'}),
      setDoc(doc(db, 'healthSnapshots/snapshot1'), {userId: 'member1'}),
      setDoc(doc(db, 'ingestionJobs/job1'), {status: 'completed'}),
      setDoc(doc(db, 'clinicalReportKeys/key1'), {reportId: 'gut1'}),
      setDoc(doc(db, 'appConfig/features'), {gut: true, blood: true, insights: true}),
    ]);
    await uploadBytes(
      ref(context.storage(), 'clinical-ingest/gut/raw.json'),
      new Uint8Array([1, 2, 3]),
    );
  });
});

function dbFor(uid, token = {}) {
  return env.authenticatedContext(uid, token).firestore();
}

describe('clinical consumer and expert projections', () => {
  test('member reads only their consumer documents', async () => {
    const owner = dbFor('member1');
    const other = dbFor('member2');
    await assertSucceeds(getDoc(doc(owner, 'gutReports/gut1')));
    await assertSucceeds(getDoc(doc(owner, 'bloodReports/blood1')));
    await assertSucceeds(getDoc(doc(owner, 'healthSnapshots/snapshot1')));
    await assertFails(getDoc(doc(owner, 'gutReportExperts/gut1')));
    await assertFails(getDoc(doc(other, 'gutReports/gut1')));
  });

  test('only assigned trainer and admin read expert documents', async () => {
    const assigned = dbFor('trainer1', {trainer: true, role: 'trainer'});
    const unassigned = dbFor('trainer2', {trainer: true, role: 'trainer'});
    const admin = dbFor('admin1', {admin: true, role: 'admin'});
    await assertSucceeds(getDoc(doc(assigned, 'gutReportExperts/gut1')));
    await assertSucceeds(getDoc(doc(assigned, 'bloodReportExperts/blood1')));
    await assertFails(getDoc(doc(unassigned, 'gutReportExperts/gut1')));
    await assertSucceeds(getDoc(doc(admin, 'gutReportExperts/gut1')));
    await assertSucceeds(getDoc(doc(admin, 'ingestionJobs/job1')));
  });

  test('lab operator has no direct member or report access', async () => {
    const lab = dbFor('lab1', {role: 'lab_operator'});
    await assertFails(getDoc(doc(lab, 'users/member1')));
    await assertFails(getDoc(doc(lab, 'bloodReports/blood1')));
    await assertFails(getDoc(doc(lab, 'bloodReportExperts/blood1')));
    await assertFails(getDoc(doc(lab, 'ingestionJobs/job1')));
  });

  test('clinical report writes are always server-only', async () => {
    const admin = dbFor('admin1', {admin: true});
    await assertFails(setDoc(doc(admin, 'gutReports/new'), {userId: 'member1'}));
    await assertFails(updateDoc(doc(admin, 'bloodReports/blood1'), {status: 'changed'}));
    await assertFails(setDoc(doc(admin, 'clinicalReportKeys/new'), {reportId: 'gut1'}));
  });
});

describe('profile privilege boundaries', () => {
  test('member can update care type but cannot promote themselves', async () => {
    const member = dbFor('member1');
    await assertSucceeds(updateDoc(doc(member, 'users/member1'), {
      careType: 'both', careTypeVersion: 1,
    }));
    await assertFails(updateDoc(doc(member, 'users/member1'), {
      role: 'admin', isApproved: true,
    }));
  });

  test('malicious privileged profile creation is rejected', async () => {
    const member = dbFor('new-member');
    await assertFails(setDoc(doc(member, 'users/new-member'), {
      role: 'admin', isApproved: true, isPremium: true,
    }));
  });

  test('admin applicants cannot approve or promote themselves', async () => {
    const applicant = dbFor('applicant1');
    const reference = doc(applicant, 'admins/applicant1');
    await assertSucceeds(setDoc(reference, {
      email: 'applicant@example.com',
      displayName: 'Applicant',
      createdAt: 1,
      approvalStatus: 'pending',
      role: 'admin',
      lastLoginAt: null,
    }));
    await assertFails(updateDoc(reference, {approvalStatus: 'approved'}));
    await assertFails(setDoc(doc(dbFor('applicant2'), 'admins/applicant2'), {
      email: 'attacker@example.com',
      displayName: 'Attacker',
      createdAt: 1,
      approvalStatus: 'approved',
      role: 'super_admin',
      lastLoginAt: null,
    }));
  });

  test('authenticated users can read feature flags', async () => {
    await assertSucceeds(getDoc(doc(dbFor('member1'), 'appConfig/features')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'appConfig/features')));
  });
});

describe('storage privilege boundaries', () => {
  test('clinical raw objects are admin-read and server-write only', async () => {
    const adminFile = ref(
      env.authenticatedContext('admin1', {admin: true}).storage(),
      'clinical-ingest/gut/raw.json',
    );
    const memberFile = ref(
      env.authenticatedContext('member1').storage(),
      'clinical-ingest/gut/raw.json',
    );
    await assertSucceeds(getBytes(adminFile));
    await assertFails(getBytes(memberFile));
    await assertFails(uploadBytes(adminFile, new Uint8Array([4])));
  });

  test('request and community uploads cannot target another user', async () => {
    const storage = env.authenticatedContext('member1').storage();
    await assertSucceeds(uploadBytes(
      ref(storage, 'requests/member1/sample.mp4'),
      new Uint8Array([1]),
    ));
    await assertFails(uploadBytes(
      ref(storage, 'requests/member2/sample.mp4'),
      new Uint8Array([1]),
    ));
    await assertSucceeds(uploadBytes(
      ref(storage, 'posts/123_member1.jpg'),
      new Uint8Array([1]),
    ));
    await assertFails(uploadBytes(
      ref(storage, 'posts/123_member2.jpg'),
      new Uint8Array([1]),
    ));
  });
});
