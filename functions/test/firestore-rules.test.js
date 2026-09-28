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
      setDoc(doc(db, 'posts/post1'), {
        authorId: 'member1', content: '건강 기록', imageUrls: [], likeCount: 0,
        commentCount: 0, createdAt: 1,
      }),
      setDoc(doc(db, 'requests/request1'), {
        userId: 'member1', userName: '가상 회원 A', type: 'postureCheck', status: 'pending',
        title: '합성 요청', description: '합성 설명', attachmentUrls: ['https://example.invalid/a.mp4'],
        createdAt: 1, updatedAt: 1,
      }),
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

describe('community integrity boundaries', () => {
  test('members cannot forge counters or write server-owned reactions', async () => {
    const member = dbFor('member1');
    await assertFails(updateDoc(doc(member, 'posts/post1'), {likeCount: 99}));
    await assertFails(setDoc(doc(member, 'posts/post1/likes/member1'), {createdAt: 1}));
    await assertFails(setDoc(doc(member, 'posts/post1/comments/comment1'), {
      authorId: 'member1', content: '조작 댓글', createdAt: 1,
    }));
  });

  test('post author can edit content but cannot change ownership', async () => {
    const owner = dbFor('member1');
    await assertSucceeds(updateDoc(doc(owner, 'posts/post1'), {content: '수정된 기록'}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {authorId: 'member2'}));
  });

  // Post.fromFirestore가 읽지 못하는 게시글 하나가 피드 전체를 실패시킨다: 수정도 작성과 같은 본문 검증을 받는다.
  test('post edits keep the create body types: content is a 1-2000 char string, imageUrls a list', async () => {
    const owner = dbFor('member1');
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {content: {}}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {content: ''}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {content: 'a'.repeat(2001)}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {imageUrls: 5}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {imageUrls: [42]}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {imageUrls: ['https://example.invalid/1.jpg', null]}));
    await assertFails(updateDoc(doc(owner, 'posts/post1'), {
      imageUrls: Array.from({length: 11}, (_, i) => `https://example.invalid/${i}.jpg`),
    }));
    await assertSucceeds(updateDoc(doc(owner, 'posts/post1'), {
      imageUrls: Array.from({length: 10}, (_, i) => `https://example.invalid/${i}.jpg`),
    }));
    await assertSucceeds(updateDoc(doc(owner, 'posts/post1'), {
      content: 'a'.repeat(2000), imageUrls: ['https://example.invalid/1.jpg'],
    }));
  });

  test('post create takes only the app keys with string author fields', async () => {
    const member = dbFor('member1');
    const post = {
      authorId: 'member1', authorName: '가상 회원 A', authorProfileImage: null, content: '새 기록',
      imageUrls: [], likeCount: 0, commentCount: 0, createdAt: 1,
    };
    await assertSucceeds(setDoc(doc(member, 'posts/post2'), post));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, authorName: {}}));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, authorProfileImage: 7}));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, imageUrls: 'x'}));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, imageUrls: [42]}));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, content: {}}));
    await assertFails(setDoc(doc(member, 'posts/post3'), {...post, pinned: true}));
  });
});

describe('request workflow boundaries', () => {
  const trainerDb = (uid) => dbFor(uid, {trainer: true, role: 'trainer'});

  test('assigned trainer updates only the workflow fields, with their own adminId', async () => {
    const assigned = trainerDb('trainer1');
    await assertSucceeds(updateDoc(doc(assigned, 'requests/request1'), {status: 'inProgress', updatedAt: 2}));
    await assertSucceeds(updateDoc(doc(assigned, 'requests/request1'), {
      status: 'completed', adminFeedback: '합성 피드백', adminId: 'trainer1', updatedAt: 3,
    }));
    await assertFails(updateDoc(doc(assigned, 'requests/request1'), {adminId: 'trainer2'}));
  });

  test('assigned trainer cannot move a request to another member or edit what the member wrote', async () => {
    const assigned = trainerDb('trainer1');
    await assertFails(updateDoc(doc(assigned, 'requests/request1'), {userId: 'member2'}));
    await assertFails(updateDoc(doc(assigned, 'requests/request1'), {userId: 'member2', status: 'completed'}));
    await assertFails(updateDoc(doc(assigned, 'requests/request1'), {title: '바뀐 제목'}));
    await assertFails(updateDoc(doc(assigned, 'requests/request1'), {
      attachmentUrls: ['https://example.invalid/b.mp4'],
    }));
  });

  test('unassigned trainer and the member cannot update, admin can', async () => {
    await assertFails(updateDoc(doc(trainerDb('trainer2'), 'requests/request1'), {status: 'completed'}));
    await assertFails(updateDoc(doc(dbFor('member1'), 'requests/request1'), {status: 'completed'}));
    await assertSucceeds(updateDoc(doc(dbFor('admin1', {admin: true}), 'requests/request1'), {
      status: 'rejected',
    }));
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
