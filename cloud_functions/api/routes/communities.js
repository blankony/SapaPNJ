const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { getPool } = require('../db');

// GET /api/communities — List / search communities
router.get('/', async (req, res) => {
  const { q, category } = req.query;
  const pool = await getPool();

  let query = `
    SELECT c.*,
      (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) as follower_count
    FROM communities c
    WHERE 1=1`;
  const params = [];

  if (q) {
    query += ' AND (c.name LIKE ? OR c.description LIKE ?)';
    params.push(`%${q}%`, `%${q}%`);
  }
  if (category) {
    query += ' AND c.category = ?';
    params.push(category);
  }

  query += ' ORDER BY c.created_at DESC LIMIT 50';

  const [rows] = await pool.execute(query, params);
  res.json(rows);
});

// GET /api/communities/my — Communities the current user follows
router.get('/my', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    `SELECT c.*,
       (SELECT COUNT(*) FROM community_members WHERE community_id = c.id) as follower_count,
       cm.role
     FROM community_members cm
     JOIN communities c ON cm.community_id = c.id
     WHERE cm.user_uid = ?
     ORDER BY c.name`,
    [req.uid]
  );
  res.json(rows);
});

// GET /api/communities/:id — Get community details
router.get('/:id', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute('SELECT * FROM communities WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Community not found' });

  const community = rows[0];

  // Get members with roles
  const [members] = await pool.execute(
    'SELECT user_uid, role FROM community_members WHERE community_id = ?',
    [req.params.id]
  );

  community.followers = members.filter(m => m.role === 'follower').map(m => m.user_uid);
  community.admins = members.filter(m => m.role === 'admin').map(m => m.user_uid);
  community.editors = members.filter(m => m.role === 'editor').map(m => m.user_uid);
  community.moderators = members.filter(m => m.role === 'moderator').map(m => m.user_uid);
  community.allMembers = members.map(m => m.user_uid);
  community.followerCount = members.length;

  res.json(community);
});

// POST /api/communities — Create a community
router.post('/', async (req, res) => {
  const {
    name, description, category = 'casual',
    is_verified = false, verification_doc_url,
    allow_member_posts = false
  } = req.body;

  if (!name) return res.status(400).json({ error: 'name is required' });

  const id = uuidv4();
  const pool = await getPool();
  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    await conn.execute(
      `INSERT INTO communities (id, name, description, category, owner_uid,
        is_verified, verification_doc_url, allow_member_posts, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [id, name, description || null, category, req.uid,
       is_verified, verification_doc_url || null, allow_member_posts]
    );

    // Owner is automatically a follower
    await conn.execute(
      `INSERT INTO community_members (community_id, user_uid, role, created_at)
       VALUES (?, ?, 'follower', NOW())`,
      [id, req.uid]
    );

    await conn.commit();
    res.status(201).json({ id });
  } catch (err) {
    await conn.rollback();
    console.error('Create community error:', err);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

// PATCH /api/communities/:id — Update community
router.patch('/:id', async (req, res) => {
  const pool = await getPool();

  // Check ownership/admin
  const [community] = await pool.execute('SELECT owner_uid FROM communities WHERE id = ?', [req.params.id]);
  if (community.length === 0) return res.status(404).json({ error: 'Community not found' });

  const [memberRole] = await pool.execute(
    'SELECT role FROM community_members WHERE community_id = ? AND user_uid = ?',
    [req.params.id, req.uid]
  );

  const isOwner = community[0].owner_uid === req.uid;
  const isAdmin = memberRole.length > 0 && memberRole[0].role === 'admin';
  if (!isOwner && !isAdmin) return res.status(403).json({ error: 'Not authorized' });

  const allowedFields = [
    'name', 'description', 'image_url', 'banner_image_url',
    'allow_member_posts', 'category'
  ];

  const updates = [];
  const values = [];
  for (const [key, value] of Object.entries(req.body)) {
    if (allowedFields.includes(key)) {
      updates.push(`${key} = ?`);
      values.push(value);
    }
  }

  if (updates.length === 0) return res.status(400).json({ error: 'Nothing to update' });

  values.push(req.params.id);
  await pool.execute(`UPDATE communities SET ${updates.join(', ')} WHERE id = ?`, values);
  res.json({ success: true });
});

// DELETE /api/communities/:id — Delete community
router.delete('/:id', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute('SELECT owner_uid FROM communities WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Community not found' });
  if (rows[0].owner_uid !== req.uid) return res.status(403).json({ error: 'Only owner can delete' });

  await pool.execute('DELETE FROM communities WHERE id = ?', [req.params.id]);
  res.json({ success: true });
});

// POST /api/communities/:id/follow — Follow/join a community
router.post('/:id/follow', async (req, res) => {
  const pool = await getPool();
  try {
    await pool.execute(
      `INSERT INTO community_members (community_id, user_uid, role, created_at)
       VALUES (?, ?, 'follower', NOW())
       ON DUPLICATE KEY UPDATE role = role`,
      [req.params.id, req.uid]
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Follow community error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/communities/:id/follow — Unfollow a community
router.delete('/:id/follow', async (req, res) => {
  const pool = await getPool();
  await pool.execute(
    'DELETE FROM community_members WHERE community_id = ? AND user_uid = ?',
    [req.params.id, req.uid]
  );
  res.json({ success: true });
});

// GET /api/communities/:id/members — Get community members with user data
router.get('/:id/members', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    `SELECT cm.role, cm.created_at as joined_at,
            u.uid, u.name, u.email, u.avatar_icon_id, u.avatar_hex, u.profile_image_url
     FROM community_members cm
     JOIN users u ON cm.user_uid = u.uid
     WHERE cm.community_id = ?
     ORDER BY
       CASE cm.role
         WHEN 'admin' THEN 1
         WHEN 'editor' THEN 2
         WHEN 'moderator' THEN 3
         ELSE 4
       END,
       cm.created_at`,
    [req.params.id]
  );
  res.json(rows);
});

// PATCH /api/communities/:id/members/:uid — Update member role
router.patch('/:id/members/:uid', async (req, res) => {
  const { role } = req.body;
  if (!['follower', 'admin', 'editor', 'moderator'].includes(role)) {
    return res.status(400).json({ error: 'Invalid role' });
  }

  const pool = await getPool();
  const [community] = await pool.execute('SELECT owner_uid FROM communities WHERE id = ?', [req.params.id]);
  if (community.length === 0) return res.status(404).json({ error: 'Community not found' });
  if (community[0].owner_uid !== req.uid) {
    const [myRole] = await pool.execute(
      'SELECT role FROM community_members WHERE community_id = ? AND user_uid = ?',
      [req.params.id, req.uid]
    );
    if (myRole.length === 0 || myRole[0].role !== 'admin') {
      return res.status(403).json({ error: 'Only owner/admin can change roles' });
    }
  }

  await pool.execute(
    'UPDATE community_members SET role = ? WHERE community_id = ? AND user_uid = ?',
    [role, req.params.id, req.params.uid]
  );
  res.json({ success: true });
});

// DELETE /api/communities/:id/members/:uid — Remove member
router.delete('/:id/members/:uid', async (req, res) => {
  const pool = await getPool();
  const [community] = await pool.execute('SELECT owner_uid FROM communities WHERE id = ?', [req.params.id]);
  if (community.length === 0) return res.status(404).json({ error: 'Community not found' });

  // Owner, admin, or the user themselves can remove
  const isOwner = community[0].owner_uid === req.uid;
  const isSelf = req.params.uid === req.uid;
  if (!isOwner && !isSelf) {
    const [myRole] = await pool.execute(
      'SELECT role FROM community_members WHERE community_id = ? AND user_uid = ?',
      [req.params.id, req.uid]
    );
    if (myRole.length === 0 || myRole[0].role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized' });
    }
  }

  await pool.execute(
    'DELETE FROM community_members WHERE community_id = ? AND user_uid = ?',
    [req.params.id, req.params.uid]
  );
  res.json({ success: true });
});

module.exports = router;

// GET /api/communities/recommended
router.get('/recommended', async (req, res) => {
  const { getPool } = require('../db');
  const pool = await getPool();
  try {
    const query = `
      SELECT c.*,
        (
          SELECT COUNT(*) FROM community_members cm
          JOIN follows f ON f.following_uid = cm.user_uid AND f.follower_uid = ?
          WHERE cm.community_id = c.id
        ) AS mutual_count,
        (SELECT COUNT(*) FROM community_members cm2 WHERE cm2.community_id = c.id) AS member_count
      FROM communities c
      WHERE c.id NOT IN (SELECT community_id FROM community_members WHERE user_uid = ?)
      ORDER BY mutual_count DESC, member_count DESC LIMIT 20
    `;
    const [rows] = await pool.execute(query, [req.uid, req.uid]);
    res.json(rows);
  } catch (err) {
    console.error('Community recommended error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
