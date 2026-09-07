// Register Shard 1 with mongos
//
// Idempotent. Connects to mongos (correct context for sh.addShard()).
// Safe to re-run: detects if shard is already registered.

print('============================================================');
print('  Registering Shard 1 with mongos');
print('============================================================\n');

var existingShards = db.adminCommand({ listShards: 1 });
var shardIds = existingShards.shards ? existingShards.shards.map(function(s) { return s._id; }) : [];

if (shardIds.indexOf('shard1ReplSet') !== -1) {
  print('OK: Shard 1 already registered with mongos\n');
} else {
  var r = sh.addShard('shard1ReplSet/oelite-shard-1:27018,oelite-shard-1-arb:27018');
  if (!r.ok) {
    throw new Error('addShard failed: ' + JSON.stringify(r));
  }
  print('OK: Shard added (' + r.shardAdded + ')\n');
}

// Final cluster status
print('Cluster status:');
print('  mongos: oelite-mongos:27017 (version ' + db.version() + ')');
var st = sh.status();
print('  shards: ' + st.shards.length + ' registered');
print('  databases: ' + Object.keys(db.adminCommand({ listDatabases: 1 }).databases).length + '\n');
