const express = require('express');
const { v4: uuidv4 } = require('uuid');
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

  const pool = await getPool();
  const targetUid = req.params.uid;

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    if (action === 'approve') {
      const [result] = await connection.query(
        'UPDATE users SET verification_status = "verified" WHERE uid = ?',
        [targetUid]
      );
      if (result.affectedRows === 0) {
        await connection.rollback();
        connection.release();
        return res.status(404).json({ error: 'User not found' });
      }
      await connection.query(
        'INSERT INTO notifications (id, user_uid, type, is_read) VALUES (?, ?, "ktm_approved", FALSE)',
        [uuidv4(), targetUid]
      );
    } else if (action === 'reject') {
      const [result] = await connection.query(
        'UPDATE users SET verification_status = "rejected", ktm_rejection_count = ktm_rejection_count + 1, ktm_last_rejected_at = NOW() WHERE uid = ?',
        [targetUid]
      );
      if (result.affectedRows === 0) {
        await connection.rollback();
        connection.release();
        return res.status(404).json({ error: 'User not found' });
      }
      await connection.query(
        'INSERT INTO notifications (id, user_uid, type, is_read) VALUES (?, ?, "ktm_rejected", FALSE)',
        [uuidv4(), targetUid]
      );
    }

    await connection.commit();
    connection.release();

    res.json({ success: true, verification_status: action === 'approve' ? 'verified' : 'rejected' });
  } catch (err) {
    if (connection) {
      await connection.rollback();
      connection.release();
    }
    console.error('Update verification error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
