const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { getPool } = require('../db');

// POST /api/users — Register / create user profile
router.post('/', async (req, res) => {
  const { uid, email, name, nim } = req.body;
  if (!uid || !email || !name) {
    return res.status(400).json({ error: 'uid, email, and name are required' });
  }

  const pool = await getPool();
  try {
    await pool.execute(
      `INSERT INTO users (uid, email, name, nim, agreed_to_terms, agreed_at, created_at)
       VALUES (?, ?, ?, ?, TRUE, NOW(), NOW())
       ON DUPLICATE KEY UPDATE name = VALUES(name)`,
      [uid, email, name, nim || null]
    );
    res.status(201).json({ success: true });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'NIM already registered', code: 'nim-already-in-use' });
    }
    console.error('Create user error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/users/:uid — Get user profile
router.get('/:uid', async (req, res) => {
  const pool = await getPool();
  try {
    const [rows] = await pool.execute('SELECT * FROM users WHERE uid = ?', [req.params.uid]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });

    const user = rows[0];

    // Get follower/following counts
    const [[{ followerCount }]] = await pool.execute(
      'SELECT COUNT(*) as followerCount FROM follows WHERE following_uid = ?', [req.params.uid]
    );
    const [[{ followingCount }]] = await pool.execute(
      'SELECT COUNT(*) as followingCount FROM follows WHERE follower_uid = ?', [req.params.uid]
    );

    // Get follower/following ID lists
    const [followerRows] = await pool.execute(
      'SELECT follower_uid FROM follows WHERE following_uid = ?', [req.params.uid]
    );
    const [followingRows] = await pool.execute(
      'SELECT following_uid FROM follows WHERE follower_uid = ?', [req.params.uid]
    );

    user.followers = followerRows.map(r => r.follower_uid);
    user.following = followingRows.map(r => r.following_uid);
    user.followerCount = followerCount;
    user.followingCount = followingCount;

    // Check if current user has a pending follow request
    const [[{ hasRequest }]] = await pool.execute(
      "SELECT COUNT(*) as hasRequest FROM follow_requests WHERE sender_uid = ? AND target_uid = ? AND status = 'pending'",
      [req.uid, req.params.uid]
    );
    user.has_follow_request = hasRequest > 0;

    res.json(user);

  } catch (err) {
    console.error('Get user error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/users/:uid — Update user profile
router.patch('/:uid', async (req, res) => {
  if (req.uid !== req.params.uid) {
    return res.status(403).json({ error: 'Cannot edit another user' });
  }

  const allowedFields = [
    'name', 'bio', 'department', 'study_program', 'department_code',
    'avatar_icon_id', 'avatar_hex', 'profile_image_url', 'banner_image_url',
    'is_private', 'pinned_post_id', 'verification_status'
  ];

  const updates = [];
  const values = [];
  for (const [key, value] of Object.entries(req.body)) {
    if (allowedFields.includes(key)) {
      updates.push(`${key} = ?`);
      values.push(value);
    }
  }

  if (updates.length === 0) return res.status(400).json({ error: 'No valid fields to update' });

  const pool = await getPool();
  try {
    values.push(req.params.uid);
    await pool.execute(`UPDATE users SET ${updates.join(', ')} WHERE uid = ?`, values);
    res.json({ success: true });
  } catch (err) {
    console.error('Update user error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/users/:uid/check-nim?nim=xxx — Check NIM availability
router.get('/:uid/check-nim', async (req, res) => {
  const { nim } = req.query;
  if (!nim) return res.status(400).json({ error: 'nim is required' });

  const pool = await getPool();
  const [rows] = await pool.execute('SELECT uid FROM users WHERE nim = ?', [nim]);
  res.json({ available: rows.length === 0 });
});

// POST /api/users/:uid/follow — Follow a user
router.post('/:uid/follow', async (req, res) => {
  const targetUid = req.params.uid;
  const myUid = req.uid;
  if (myUid === targetUid) return res.status(400).json({ error: 'Cannot follow yourself' });

  const pool = await getPool();
  try {
    // Check if target is private
    const [targetRows] = await pool.execute('SELECT is_private FROM users WHERE uid = ?', [targetUid]);
    if (targetRows.length === 0) return res.status(404).json({ error: 'User not found' });

    if (targetRows[0].is_private) {
      // Create follow request
      await pool.execute(
        `INSERT INTO follow_requests (sender_uid, target_uid, status, created_at)
         VALUES (?, ?, 'pending', NOW())
         ON DUPLICATE KEY UPDATE status = 'pending', created_at = NOW()`,
        [myUid, targetUid]
      );
      // Create notification
      const notifId = uuidv4();
      await pool.execute(
        `INSERT INTO notifications (id, user_uid, sender_uid, type, created_at)
         VALUES (?, ?, ?, 'follow_request', NOW())`,
        [notifId, targetUid, myUid]
      );
      return res.json({ success: true, type: 'request_sent' });
    }

    // Direct follow
    await pool.execute(
      'INSERT IGNORE INTO follows (follower_uid, following_uid, created_at) VALUES (?, ?, NOW())',
      [myUid, targetUid]
    );

    // Notification
    const notifId = uuidv4();
    await pool.execute(
      `INSERT INTO notifications (id, user_uid, sender_uid, type, created_at)
       VALUES (?, ?, ?, 'follow', NOW())`,
      [notifId, targetUid, myUid]
    );

    res.json({ success: true, type: 'followed' });
  } catch (err) {
    console.error('Follow error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/users/:uid/follow — Unfollow a user
router.delete('/:uid/follow', async (req, res) => {
  const targetUid = req.params.uid;
  const myUid = req.uid;

  const pool = await getPool();
  try {
    await pool.execute('DELETE FROM follows WHERE follower_uid = ? AND following_uid = ?', [myUid, targetUid]);
    // Also clean up any pending follow request
    await pool.execute('DELETE FROM follow_requests WHERE sender_uid = ? AND target_uid = ?', [myUid, targetUid]);
    res.json({ success: true });
  } catch (err) {
    console.error('Unfollow error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/users/:uid/follow/accept — Accept a follow request
router.post('/:uid/follow/accept', async (req, res) => {
  const myUid = req.params.uid;
  const { senderUid } = req.body;
  if (req.uid !== myUid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute(
      "UPDATE follow_requests SET status = 'accepted' WHERE sender_uid = ? AND target_uid = ?",
      [senderUid, myUid]
    );
    await conn.execute(
      'INSERT IGNORE INTO follows (follower_uid, following_uid, created_at) VALUES (?, ?, NOW())',
      [senderUid, myUid]
    );
    const notifId = uuidv4();
    await conn.execute(
      `INSERT INTO notifications (id, user_uid, sender_uid, type, created_at)
       VALUES (?, ?, ?, 'follow', NOW())`,
      [notifId, senderUid, myUid]
    );
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    console.error('Accept follow error:', err);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

// POST /api/users/:uid/follow/decline — Decline a follow request
router.post('/:uid/follow/decline', async (req, res) => {
  const myUid = req.params.uid;
  const { senderUid } = req.body;
  if (req.uid !== myUid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  try {
    await pool.execute(
      "DELETE FROM follow_requests WHERE sender_uid = ? AND target_uid = ?",
      [senderUid, myUid]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Decline follow error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/users/:uid/followers/:followerUid — Remove a follower
router.delete('/:uid/followers/:followerUid', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  try {
    await pool.execute(
      'DELETE FROM follows WHERE follower_uid = ? AND following_uid = ?',
      [req.params.followerUid, req.params.uid]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Remove follower error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/users/:uid/followers — Get follower UIDs
router.get('/:uid/followers', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT follower_uid FROM follows WHERE following_uid = ?', [req.params.uid]
  );
  res.json(rows.map(r => r.follower_uid));
});

// GET /api/users/:uid/following — Get following UIDs
router.get('/:uid/following', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT following_uid FROM follows WHERE follower_uid = ?', [req.params.uid]
  );
  res.json(rows.map(r => r.following_uid));
});

// GET /api/users/:uid/notifications — Get notifications
router.get('/:uid/notifications', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [rows] = await pool.execute(
    `SELECT n.*, u.name as sender_name, u.profile_image_url as sender_avatar,
            u.avatar_icon_id as sender_icon_id, u.avatar_hex as sender_hex
     FROM notifications n
     LEFT JOIN users u ON n.sender_uid = u.uid
     WHERE n.user_uid = ?
     ORDER BY n.created_at DESC
     LIMIT 50`,
     [req.params.uid]
  );
  res.json(rows);
});

// PATCH /api/users/:uid/notifications — Mark all notifications as read
router.patch('/:uid/notifications', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('UPDATE notifications SET is_read = TRUE WHERE user_uid = ?', [req.params.uid]);
  res.json({ success: true });
});

// PATCH /api/users/:uid/notifications/:notifId — Mark notification read
router.patch('/:uid/notifications/:notifId', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('UPDATE notifications SET is_read = TRUE WHERE id = ? AND user_uid = ?',
    [req.params.notifId, req.params.uid]);
  res.json({ success: true });
});

// DELETE /api/users/:uid/notifications — Clear notification history
router.delete('/:uid/notifications', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('DELETE FROM notifications WHERE user_uid = ?', [req.params.uid]);
  res.json({ success: true });
});


// GET /api/users/:uid/bookmarks — Get bookmarked posts
router.get('/:uid/bookmarks', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [rows] = await pool.execute(
    `SELECT p.*, u.name as user_name, u.email as user_email,
            u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
            (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) as like_count,
            EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_uid = ?) as is_liked,
            EXISTS(SELECT 1 FROM bookmarks WHERE post_id = p.id AND user_uid = ?) as is_bookmarked
     FROM bookmarks b
     JOIN posts p ON b.post_id = p.id
     JOIN users u ON p.user_uid = u.uid
     WHERE b.user_uid = ?
     ORDER BY b.created_at DESC`,
    [req.params.uid, req.params.uid, req.params.uid]
  );
  res.json(rows);
});

// POST /api/users/:uid/bookmarks/:postId — Toggle bookmark
router.post('/:uid/bookmarks/:postId', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [existing] = await pool.execute(
    'SELECT 1 FROM bookmarks WHERE user_uid = ? AND post_id = ?',
    [req.params.uid, req.params.postId]
  );

  if (existing.length > 0) {
    await pool.execute('DELETE FROM bookmarks WHERE user_uid = ? AND post_id = ?',
      [req.params.uid, req.params.postId]);
    res.json({ bookmarked: false });
  } else {
    await pool.execute('INSERT INTO bookmarks (user_uid, post_id, created_at) VALUES (?, ?, NOW())',
      [req.params.uid, req.params.postId]);
    res.json({ bookmarked: true });
  }
});

// GET /api/users/:uid/blocked — Get blocked user IDs
router.get('/:uid/blocked', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT blocked_uid FROM blocked_users WHERE blocker_uid = ?', [req.params.uid]
  );
  res.json(rows.map(r => r.blocked_uid));
});

// POST /api/users/:uid/block/:targetUid — Block a user
router.post('/:uid/block/:targetUid', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute(
      'INSERT IGNORE INTO blocked_users (blocker_uid, blocked_uid, created_at) VALUES (?, ?, NOW())',
      [req.params.uid, req.params.targetUid]
    );
    // Also unfollow each other
    await conn.execute('DELETE FROM follows WHERE follower_uid = ? AND following_uid = ?',
      [req.params.uid, req.params.targetUid]);
    await conn.execute('DELETE FROM follows WHERE follower_uid = ? AND following_uid = ?',
      [req.params.targetUid, req.params.uid]);
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    console.error('Block error:', err);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

// DELETE /api/users/:uid/block/:targetUid — Unblock a user
router.delete('/:uid/block/:targetUid', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('DELETE FROM blocked_users WHERE blocker_uid = ? AND blocked_uid = ?',
    [req.params.uid, req.params.targetUid]);
  res.json({ success: true });
});

// GET /api/users/:uid/chat-sessions — Get AI chat sessions
router.get('/:uid/chat-sessions', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT * FROM chat_sessions WHERE user_uid = ? ORDER BY last_updated DESC',
    [req.params.uid]
  );
  res.json(rows);
});

// POST /api/users/:uid/chat-sessions — Create chat session
router.post('/:uid/chat-sessions', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const id = uuidv4();
  const pool = await getPool();
  await pool.execute(
    'INSERT INTO chat_sessions (id, user_uid, title, last_updated) VALUES (?, ?, ?, NOW())',
    [id, req.params.uid, req.body.title || 'New Conversation']
  );
  res.status(201).json({ id });
});

// DELETE /api/users/:uid/chat-sessions/:sessionId — Delete chat session
router.delete('/:uid/chat-sessions/:sessionId', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('DELETE FROM chat_sessions WHERE id = ? AND user_uid = ?',
    [req.params.sessionId, req.params.uid]);
  res.json({ success: true });
});

// GET /api/users/:uid/chat-sessions/:sessionId/messages — Get chat messages for a session
router.get('/:uid/chat-sessions/:sessionId/messages', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT * FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC',
    [req.params.sessionId]
  );
  res.json(rows);
});

// POST /api/users/:uid/chat-sessions/:sessionId/messages — Save a chat message
router.post('/:uid/chat-sessions/:sessionId/messages', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const id = uuidv4();
  const pool = await getPool();
  await pool.execute(
    'INSERT INTO chat_messages (id, session_id, text, is_user, timestamp) VALUES (?, ?, ?, ?, NOW())',
    [id, req.params.sessionId, req.body.text, req.body.isUser]
  );
  res.status(201).json({ id });
});

// DELETE /api/users/:uid — Delete user profile (cascades to all user data)
router.delete('/:uid', async (req, res) => {
  if (req.uid !== req.params.uid) return res.status(403).json({ error: 'Forbidden' });

  const pool = await getPool();
  await pool.execute('DELETE FROM users WHERE uid = ?', [req.params.uid]);
  res.json({ success: true });
});

// POST /api/users/:uid/report — Report a user
router.post('/:uid/report', async (req, res) => {
  // For now just log it; in production you'd store reports in a table
  console.log(`Report: user ${req.uid} reported ${req.params.uid} for: ${req.body.reason}`);
  res.json({ success: true });
});

// GET /api/users?q=query — Search users / Get suggestions
router.get('/', async (req, res) => {
  const { q } = req.query;
  const pool = await getPool();

  if (!q || q.length < 2) {
    // Return suggested users (not followed by current user, not current user)
    const [rows] = await pool.execute(
      `SELECT uid, name, email, avatar_icon_id, avatar_hex, profile_image_url,
              verification_status, department_code
       FROM users
       WHERE uid != ? AND uid NOT IN (
         SELECT following_uid FROM follows WHERE follower_uid = ?
       )
       LIMIT 20`,
      [req.uid, req.uid]
    );
    return res.json(rows);
  }

  const [rows] = await pool.execute(
    `SELECT uid, name, email, avatar_icon_id, avatar_hex, profile_image_url,
            verification_status, department_code
     FROM users
     WHERE name LIKE ? OR email LIKE ?
     LIMIT 20`,
    [`%${q}%`, `%${q}%`]
  );
  res.json(rows);
});

module.exports = router;
