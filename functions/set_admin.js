const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const uid = process.argv[2];

if (!uid) {
  console.error('Usage: node set_admin.js <UID>');
  process.exit(1);
}

async function setAdminClaim(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    console.log(`Successfully set admin claim for user: ${uid}`);
    
    // Verify
    const user = await admin.auth().getUser(uid);
    console.log('Current Claims:', user.customClaims);
    
    process.exit(0);
  } catch (error) {
    console.error('Error setting admin claim:', error);
    process.exit(1);
  }
}

setAdminClaim(uid);
