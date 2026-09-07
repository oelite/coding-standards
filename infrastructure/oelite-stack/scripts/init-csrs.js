// Initialize MongoDB Config Server Replica Set (CSRS)
//
// Idempotent. Connects DIRECTLY to the first config server node (not mongos),
// which is the correct context for replica set operations.
//
// Safe to re-run: detects if CSRS is already initialized and skips re-init.

const CSRS_NAME = 'configReplSet';
var MEMBERS = [
  { _id: 0, host: 'oelite-configsvr-1:27019', priority: 2 },
  { _id: 1, host: 'oelite-configsvr-2:27019', priority: 1 },
  { _id: 2, host: 'oelite-configsvr-3:27019', priority: 1 },
];

print('============================================================');
print('  MongoDB Config Server Replica Set Initializer');
print('  (connecting to: oelite-configsvr-1:27019)');
print('============================================================\n');

// ── Detect existing CSRS ─────────────────────────────────────────
let cfgReady = false;
try {
  const s = rs.status();
  if (s.set === CSRS_NAME) {
    cfgReady = true;
    const primary = s.members.find(m => m.stateStr === 'PRIMARY');
    print('OK: CSRS already initialized (' + s.members.length + ' members)');
    if (primary) print('     PRIMARY: ' + primary.name);
    print('');
  }
} catch (e) {
  // rs.status() throws when replica set is not initialized — expected on first run
  print('CSRS not yet initialized. Proceeding with init...\n');
}

if (!cfgReady) {
  print('Initiating Config Server Replica Set...');
  rs.initiate({
    _id: CSRS_NAME,
    configsvr: true,
    members: MEMBERS,
  });

  // Wait for PRIMARY election
  for (let i = 0; i < 30; i++) {
    sleep(2000);
    try {
      if (rs.status().myState === 1) { cfgReady = true; break; }
    } catch (e) {}
  }

  if (!cfgReady) {
    throw new Error('CSRS PRIMARY election timeout (60s)');
  }
  print('OK: CSRS PRIMARY elected\n');
}

print('✅ Config Server Replica Set ready.\n');
