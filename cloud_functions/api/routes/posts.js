const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { getPool } = require('../db');

// GET /api/posts — Home feed with pagination and visibility filtering
router.get('/', async (req, res) => {
  const myUid = req.uid;
  const { cursor, limit = 20, community_id, user_uid, q } = req.query;
  const pageLimit = Math.min(parseInt(limit) || 20, 50);

  const pool = await getPool();
  try {
    let query, params;

    if (q) {
      // Search public posts matching q (or my own posts)
      query = `
        SELECT p.*, u.name as user_name, u.email as user_email,
               u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
               c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
        FROM posts p
        JOIN users u ON p.user_uid = u.uid
        LEFT JOIN communities c ON p.community_id = c.id
        WHERE (p.visibility = 'public' OR p.user_uid = ?)
          AND p.text LIKE ?
        ${cursor ? 'AND p.created_at < ?' : ''}
        ORDER BY p.created_at DESC
        LIMIT ?`;
      params = cursor ? [myUid, `%${q}%`, cursor, pageLimit] : [myUid, `%${q}%`, pageLimit];
    } else if (community_id) {
      // Community feed
      query = `
        SELECT p.*, u.name as user_name, u.email as user_email,
               u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
               c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
        FROM posts p
        JOIN users u ON p.user_uid = u.uid
        LEFT JOIN communities c ON p.community_id = c.id
        WHERE p.community_id = ?
        ${cursor ? 'AND p.created_at < ?' : ''}
        ORDER BY p.created_at DESC
        LIMIT ?`;
      params = cursor ? [community_id, cursor, pageLimit] : [community_id, pageLimit];
    } else if (user_uid) {
      // User's own posts
      query = `
        SELECT p.*, u.name as user_name, u.email as user_email,
               u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
               c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
        FROM posts p
        JOIN users u ON p.user_uid = u.uid
        LEFT JOIN communities c ON p.community_id = c.id
        WHERE p.user_uid = ? AND p.community_id IS NULL AND p.is_repost = FALSE
        ${cursor ? 'AND p.created_at < ?' : ''}
        ORDER BY p.created_at DESC
        LIMIT ?`;
      params = cursor ? [user_uid, cursor, pageLimit] : [user_uid, pageLimit];
    } else {
      // Home feed — public posts + followers-only from people I follow
      query = `
        SELECT p.*, u.name as user_name, u.email as user_email,
               u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
               c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
        FROM posts p
        JOIN users u ON p.user_uid = u.uid
        LEFT JOIN communities c ON p.community_id = c.id
        WHERE p.community_id IS NULL
          AND (
            p.visibility = 'public'
            OR (p.visibility = 'followers' AND (p.user_uid = ? OR EXISTS(
              SELECT 1 FROM follows WHERE follower_uid = ? AND following_uid = p.user_uid
            )))
            OR (p.visibility = 'private' AND p.user_uid = ?)
          )
        ${cursor ? 'AND p.created_at < ?' : ''}
        ORDER BY p.created_at DESC
        LIMIT ?`;
      params = cursor
        ? [myUid, myUid, myUid, cursor, pageLimit]
        : [myUid, myUid, myUid, pageLimit];
    }

    const [posts] = await pool.query(query, params);

    // Enrich with like/bookmark status and counts
    for (const post of posts) {
      const [[{ likeCount }]] = await pool.execute(
        'SELECT COUNT(*) as likeCount FROM post_likes WHERE post_id = ?', [post.id]
      );
      const [[{ isLiked }]] = await pool.execute(
        'SELECT COUNT(*) as isLiked FROM post_likes WHERE post_id = ? AND user_uid = ?',
        [post.id, myUid]
      );
      const [[{ isBookmarked }]] = await pool.execute(
        'SELECT COUNT(*) as isBookmarked FROM bookmarks WHERE post_id = ? AND user_uid = ?',
        [post.id, myUid]
      );
      post.like_count = likeCount;
      post.is_liked = isLiked > 0;
      post.is_bookmarked = isBookmarked > 0;

      // Parse media_urls JSON
      if (post.media_urls && typeof post.media_urls === 'string') {
        post.media_urls = JSON.parse(post.media_urls);
      }
    }

    res.json(posts);
  } catch (err) {
    console.error('Get posts error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/posts/reposts?user_uid=xxx — Get reposts by a user
router.get('/reposts', async (req, res) => {
  const { user_uid, cursor, limit = 20 } = req.query;
  if (!user_uid) return res.status(400).json({ error: 'user_uid required' });

  const pool = await getPool();
  const pageLimit = Math.min(parseInt(limit) || 20, 50);

  let query = `
    SELECT p.*, u.name as user_name, u.email as user_email,
           u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
           c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
    FROM posts p
    JOIN users u ON p.user_uid = u.uid
    LEFT JOIN communities c ON p.community_id = c.id
    WHERE p.user_uid = ? AND p.is_repost = TRUE
    ${cursor ? 'AND p.created_at < ?' : ''}
    ORDER BY p.created_at DESC
    LIMIT ?`;
  const params = cursor ? [user_uid, cursor, pageLimit] : [user_uid, pageLimit];

  const [posts] = await pool.query(query, params);
  res.json(posts);
});

// GET /api/posts/:id — Get single post
router.get('/:id', async (req, res) => {
  const pool = await getPool();
  try {
    const [rows] = await pool.execute(
      `SELECT p.*, u.name as user_name, u.email as user_email,
              u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
              c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
       FROM posts p
       JOIN users u ON p.user_uid = u.uid
       LEFT JOIN communities c ON p.community_id = c.id
       WHERE p.id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Post not found' });

    const post = rows[0];
    if (post.media_urls && typeof post.media_urls === 'string') {
      post.media_urls = JSON.parse(post.media_urls);
    }

    const [[{ likeCount }]] = await pool.execute(
      'SELECT COUNT(*) as likeCount FROM post_likes WHERE post_id = ?', [post.id]
    );
    const [[{ isLiked }]] = await pool.execute(
      'SELECT COUNT(*) as isLiked FROM post_likes WHERE post_id = ? AND user_uid = ?',
      [post.id, req.uid]
    );
    const [[{ isBookmarked }]] = await pool.execute(
      'SELECT COUNT(*) as isBookmarked FROM bookmarks WHERE post_id = ? AND user_uid = ?',
      [post.id, req.uid]
    );

    post.like_count = likeCount;
    post.is_liked = isLiked > 0;
    post.is_bookmarked = isBookmarked > 0;

    // Get likes UIDs
    const [likeRows] = await pool.execute(
      'SELECT user_uid FROM post_likes WHERE post_id = ?', [post.id]
    );
    post.likes = likeRows.map(r => r.user_uid);

    res.json(post);
  } catch (err) {
    console.error('Get post error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/posts — Create a post
router.post('/', async (req, res) => {
  const {
    text, media_urls, media_type, visibility = 'public',
    community_id, community_name, community_icon, community_verified,
    is_community_identity, is_repost, original_post_id
  } = req.body;

  const id = uuidv4();
  const pool = await getPool();

  try {
    await pool.execute(
      `INSERT INTO posts (id, user_uid, text, media_urls, media_type, visibility,
        community_id, is_community_identity, is_repost, original_post_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        id, req.uid, text || null,
        media_urls ? JSON.stringify(media_urls) : null,
        media_type || null, visibility,
        community_id || null,
        is_community_identity || false,
        is_repost || false,
        original_post_id || null
      ]
    );

    // If repost, increment repost count on original
    if (is_repost && original_post_id) {
      await pool.execute(
        'UPDATE posts SET repost_count = repost_count + 1 WHERE id = ?',
        [original_post_id]
      );
    }

    res.status(201).json({ id });
  } catch (err) {
    console.error('Create post error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/posts/:id — Edit a post
router.patch('/:id', async (req, res) => {
  const { text, media_urls, visibility } = req.body;
  const pool = await getPool();

  // Verify ownership
  const [rows] = await pool.execute('SELECT user_uid FROM posts WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Post not found' });
  if (rows[0].user_uid !== req.uid) return res.status(403).json({ error: 'Not your post' });

  const updates = [];
  const values = [];
  if (text !== undefined) { updates.push('text = ?'); values.push(text); }
  if (media_urls !== undefined) { updates.push('media_urls = ?'); values.push(JSON.stringify(media_urls)); }
  if (visibility !== undefined) { updates.push('visibility = ?'); values.push(visibility); }

  if (updates.length === 0) return res.status(400).json({ error: 'Nothing to update' });

  values.push(req.params.id);
  await pool.execute(`UPDATE posts SET ${updates.join(', ')} WHERE id = ?`, values);
  res.json({ success: true });
});

// DELETE /api/posts/:id — Delete a post
router.delete('/:id', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute('SELECT user_uid, is_repost, original_post_id FROM posts WHERE id = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Post not found' });
  if (rows[0].user_uid !== req.uid) return res.status(403).json({ error: 'Not your post' });

  // Decrement repost count if it was a repost
  if (rows[0].is_repost && rows[0].original_post_id) {
    await pool.execute(
      'UPDATE posts SET repost_count = GREATEST(repost_count - 1, 0) WHERE id = ?',
      [rows[0].original_post_id]
    );
  }

  await pool.execute('DELETE FROM posts WHERE id = ?', [req.params.id]);
  res.json({ success: true });
});

// POST /api/posts/:id/like — Toggle like
router.post('/:id/like', async (req, res) => {
  const pool = await getPool();
  const [existing] = await pool.execute(
    'SELECT 1 FROM post_likes WHERE post_id = ? AND user_uid = ?',
    [req.params.id, req.uid]
  );

  if (existing.length > 0) {
    await pool.execute('DELETE FROM post_likes WHERE post_id = ? AND user_uid = ?',
      [req.params.id, req.uid]);
    await pool.execute('UPDATE posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = ?', [req.params.id]);
    res.json({ liked: false });
  } else {
    await pool.execute('INSERT INTO post_likes (post_id, user_uid, created_at) VALUES (?, ?, NOW())',
      [req.params.id, req.uid]);
    await pool.execute('UPDATE posts SET like_count = like_count + 1 WHERE id = ?', [req.params.id]);

    // Notification to post owner
    const [postRows] = await pool.execute('SELECT user_uid FROM posts WHERE id = ?', [req.params.id]);
    if (postRows.length > 0 && postRows[0].user_uid !== req.uid) {
      const notifId = uuidv4();
      await pool.execute(
        `INSERT INTO notifications (id, user_uid, sender_uid, type, post_id, created_at)
         VALUES (?, ?, ?, 'like', ?, NOW())`,
        [notifId, postRows[0].user_uid, req.uid, req.params.id]
      );
    }

    res.json({ liked: true });
  }
});

// GET /api/posts/:id/comments — Get comments
router.get('/:id/comments', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    `SELECT c.*, u.name as user_name, u.email as user_email,
            u.avatar_icon_id, u.avatar_hex, u.profile_image_url
     FROM comments c
     JOIN users u ON c.user_uid = u.uid
     WHERE c.post_id = ?
     ORDER BY c.created_at ASC`,
    [req.params.id]
  );
  res.json(rows);
});

// POST /api/posts/:id/comments — Add a comment
router.post('/:id/comments', async (req, res) => {
  const { text, media_url, media_type } = req.body;
  const id = uuidv4();

  const pool = await getPool();
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    await conn.execute(
      `INSERT INTO comments (id, post_id, user_uid, text, media_url, media_type, created_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [id, req.params.id, req.uid, text || null, media_url || null, media_type || null]
    );

    await conn.execute(
      'UPDATE posts SET comment_count = comment_count + 1 WHERE id = ?',
      [req.params.id]
    );

    // Notification to post owner
    const [postRows] = await conn.execute('SELECT user_uid FROM posts WHERE id = ?', [req.params.id]);
    if (postRows.length > 0 && postRows[0].user_uid !== req.uid) {
      const notifId = uuidv4();
      let snippet = text || `Sent a ${media_type || 'media'} attachment`;
      if (snippet.length > 50) snippet = snippet.substring(0, 50) + '...';

      await conn.execute(
        `INSERT INTO notifications (id, user_uid, sender_uid, type, post_id, post_text_snippet, created_at)
         VALUES (?, ?, ?, 'comment', ?, ?, NOW())`,
        [notifId, postRows[0].user_uid, req.uid, req.params.id, snippet]
      );
    }

    await conn.commit();
    res.status(201).json({ id });
  } catch (err) {
    await conn.rollback();
    console.error('Add comment error:', err);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

// DELETE /api/posts/:postId/comments/:commentId — Delete a comment
router.delete('/:postId/comments/:commentId', async (req, res) => {
  const pool = await getPool();
  const [rows] = await pool.execute(
    'SELECT user_uid FROM comments WHERE id = ? AND post_id = ?',
    [req.params.commentId, req.params.postId]
  );
  if (rows.length === 0) return res.status(404).json({ error: 'Comment not found' });

  // Allow comment owner or post owner to delete
  const [postRows] = await pool.execute('SELECT user_uid FROM posts WHERE id = ?', [req.params.postId]);
  if (rows[0].user_uid !== req.uid && (postRows.length === 0 || postRows[0].user_uid !== req.uid)) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute('DELETE FROM comments WHERE id = ?', [req.params.commentId]);
    await conn.execute('UPDATE posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = ?', [req.params.postId]);
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

module.exports = router;
