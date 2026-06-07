const express = require('express');
const router = express.Router();
const { getPool } = require('../db');

// GET /api/admin/verifications — List pending KTM verifications
router.get('/verifications', async (req, res) => {
  const pool = await getPool();
  try {
    const [rows] = await pool.execute(
      `SELECT uid, email, name, nim, ktm_image_url, verification_status,
              profile_image_url, avatar_icon_id, avatar_hex, department_code, created_at
       FROM users
       WHERE verification_status = 'pending'
       ORDER BY created_at ASC`
    );
    res.json(rows);
  } catch (err) {
    console.error('Get verifications error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/admin/verifications/:uid — Approve or reject verification
router.patch('/verifications/:uid', async (req, res) => {
  const { action } = req.body;
  if (action !== 'approve' && action !== 'reject') {
    return res.status(400).json({ error: 'Invalid action. Must be "approve" or "reject"' });
  }

  const newStatus = action === 'approve' ? 'verified' : 'rejected';
  const pool = await getPool();
  try {
    const [result] = await pool.execute(
      'UPDATE users SET verification_status = ? WHERE uid = ?',
      [newStatus, req.params.uid]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ success: true, verification_status: newStatus });
  } catch (err) {
    console.error('Update verification error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
