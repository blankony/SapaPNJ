const { getPool } = require('../db');

async function adminMiddleware(req, res, next) {
  const pool = await getPool();
  try {
    const [rows] = await pool.execute('SELECT role FROM users WHERE uid = ?', [req.uid]);
    if (rows.length === 0 || rows[0].role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    next();
  } catch (err) {
    console.error('Admin middleware error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}

module.exports = { adminMiddleware };
