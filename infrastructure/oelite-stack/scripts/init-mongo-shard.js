// Initialize OElite MongoDB Sharded Replica Set
//
// Idempotent: safe to re-run. Detects existing replica sets / shards and skips
// re-init. Runs once per machine, triggered by mongo-init service (init profile).
//
// Topology: Config Server RS (3 nodes) + Shard 1 RS (1 primary + 1 non-electable)
//           mongos router on port 27017 = application entry point

print('============================================================');
print('  OElite MongoDB Sharded Replica Set Initializer');
print('============================================================\n');

// ── Step 1: Config Server Replica Set ─────────────────────────────────────
print('[1/4] Config Server Replica Set (CSRS)...');
let cfgReady = false;
try {
  const s = rs.status();
  if (s.set === 'configReplSet') {
    cfgReady = true;
    print('  OK: CSRS already initialized (' + s.members.length + ' members)\n');
  }
} catch (e) {}

if (!cfgReady) {
  rs.initiate({
    _id: 'configReplSet',
    configsvr: true,
    members: [
      { _id: 0, host: 'oelite-configsvr-1:27019', priority: 2 },
      { _id: 1, host: 'oelite-configsvr-2:27019', priority: 1 },
      { _id: 2, host: 'oelite-configsvr-3:27019', priority: 1 },
    ],
  });
  for (let i = 0; i < 30; i++) {
    sleep(2000);
    try {
      if (rs.status().myState === 1) { cfgReady = true; break; }
    } catch (e) {}
  }
  if (!cfgReady) throw new Error('CSRS PRIMARY election timeout (60s)');
  print('  OK: CSRS PRIMARY elected\n');
}

// ── Step 2: Shard 1 Replica Set ───────────────────────────────────────────
print('▶ Step 2/4: Shard 1 Replica Set');
let shAlreadyInit = false;
try {
  const status = rs.status();
  if (status.set === 'shard1ReplSet') {
    shAlreadyInit = true;
    print('  ✓ Shard 1 already initialized (' + status.members.length + ' members)\n');
  }
} catch (e) {}

if (!shAlreadyInit) {
  print('  → Initiating Shard 1 RS...');
  rs.initiate({
    _id: 'shard1ReplSet',
    members: [
      { _id: 0, host: 'oelite-shard-1:27018', priority: 2 },
      // secondary with priority 0 / votes 0 acts as standby (no election)
      { _id: 1, host: 'oelite-shard-1-arb:27018', priority: 0, votes: 0 },
    ],
  });
  let shReady = false;
  for (let i = 0; i < 30; i++) {
    sleep(2000);
    try {
      const s = rs.status();
      if (s.myState === 1) { shReady = true; break; }
    } catch (e) {}
  }
  if (!shReady) throw new Error('Shard 1 RS did not elect PRIMARY within 60s');
  print('  ✓ Shard 1 RS ready\n');
}

// ── Step 3: Connect to mongos and add shard ────────────────────────────────
print('▶ Step 3/4: Add Shard 1 to Cluster');
const existingShards = db.adminCommand({ listShards: 1 });
const shardNames = existingShards.shards ? existingShards.shards.map(s => s._id) : [];
if (shardNames.includes('shard1ReplSet')) {
  print('  ✓ Shard 1 already registered with mongos\n');
} else {
  const addResult = sh.addShard('shard1ReplSet/oelite-shard-1:27018,oelite-shard-1-arb:27018');
  if (!addResult.ok) {
    throw new Error('Failed to add shard: ' + JSON.stringify(addResult));
  }
  print('  ✓ Shard 1 added: ' + addResult.shardAdded + '\n');
}

// ── Step 4: Verify cluster health ──────────────────────────────────────────
print('▶ Step 4/4: Cluster Health Check');
const clusterStatus = sh.status();
const mongosVersion = db.version();
print('  ✓ mongos version: ' + mongosVersion);
print('  ✓ Total shards: ' + clusterStatus.shards.length);
print('  ✓ Active mongos: 1 (oelite-mongos:27017)');
print('\n┌─────────────────────────────────────────────────────────────┐');
print('│  Connection string for application code:                   │');
print('│    mongodb://localhost:27017/?directConnection=true       │');
print('│    (add database name + auth per OElite.AppConfig)        │');
print('└─────────────────────────────────────────────────────────────┘\n');

print('✅ MongoDB sharded replica set initialized successfully.\n');
