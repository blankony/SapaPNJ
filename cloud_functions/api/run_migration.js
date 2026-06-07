require('dotenv').config({ path: '../../.env' });
const { getPool } = require('./db');
const fs = require('fs');

async function run() {
  try {
    const pool = await getPool();
    const sql = fs.readFileSync('./migrations/004_admin_ktm_pipeline.sql', 'utf8');
    const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);
    
    for (const stmt of statements) {
      if (stmt.startsWith('--')) continue;
      console.log('Executing:', stmt);
      await pool.query(stmt);
    }
    console.log('Migration successful!');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  }
}
run();
