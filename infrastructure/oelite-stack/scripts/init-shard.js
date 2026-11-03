// Initialize MongoDB Shard 1 Replica Set
//
// Idempotent. Connects DIRECTLY to the shard primary node (not mongos),
// which is the correct context for replica set operations.

var SHARD_NAME = 'shard1ReplSet';
var MEMBERS = [
  { _id: 0, host: 'oelite-shard-1:27018', priority: 2 },
  { _id: 1, host: 'oelite-shard-1-arb:27018', priority: 0, votes: 0 },
];

print('============================================================');
print('  MongoDB Shard 1 Replica Set Initializer');
print('  (connecting to: oelite-shard-1:27018)');
print('============================================================\n');

var shReady = false;
try {
  var s = rs.status();
  if (s.set === SHARD_NAME) {
    shReady = true;
    print('OK: Shard 1 already initialized (' + s.members.length + ' members)\n');
  }
} catch (e) {
  print('Shard 1 not yet initialized. Proceeding with init...\n');
}

if (!shReady) {
  print('Initiating Shard 1 Replica Set...');
  rs.initiate({ _id: SHARD_NAME, members: MEMBERS });

  for (var i = 0; i < 30; i++) {
    sleep(2000);
    try { if (rs.status().myState === 1) { shReady = true; break; } } catch (e) {}
  }

  if (!shReady) throw new Error('Shard 1 PRIMARY election timeout (60s)');
  print('OK: Shard 1 PRIMARY elected\n');
}

print('✅ Shard 1 ready.\n');
