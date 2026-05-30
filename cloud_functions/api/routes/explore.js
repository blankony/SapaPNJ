const express = require('express');
const router = express.Router();
const { getPool } = require('../db');

// GET /api/explore/trending
router.get('/trending', async (req, res) => {
  const pool = await getPool();
  try {
    // Fetch recent posts to analyze trends (last 7 days to keep it relevant)
    const [posts] = await pool.execute('SELECT id, text FROM posts WHERE created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)');
    
    const phraseDocMap = new Map();
    const stopWords = new Set([
      'the', 'and', 'is', 'to', 'in', 'of', 'for', 'on', 'at', 'this',
      'di', 'dan', 'yang', 'ini', 'itu', 'ke', 'dari', 'ada', 'dengan',
      'untuk', 'yg', 'gak', 'ya', 'aja', 'si', 'saya', 'aku', 'bisa', 'mau',
      'banget', 'sama', 'sudah', 'lagi', 'apa', 'kapan', 'dimana'
    ]);

    for (const post of posts) {
      if (!post.text) continue;
      const text = post.text.toLowerCase();
      const cleanText = text.replace(/[^\w\s#]/g, '');
      const words = cleanText.split(/\s+/).filter(w => w.length > 0);

      for (let i = 0; i < words.length; i++) {
        if (words[i].startsWith('#')) {
          if (!phraseDocMap.has(words[i])) phraseDocMap.set(words[i], new Set());
          phraseDocMap.get(words[i]).add(post.id);
        }

        if (i < words.length - 1) {
          if (!stopWords.has(words[i]) && !stopWords.has(words[i+1])) {
             const bigram = `${words[i]} ${words[i+1]}`;
             if (!phraseDocMap.has(bigram)) phraseDocMap.set(bigram, new Set());
             phraseDocMap.get(bigram).add(post.id);
          }
        }
        if (i < words.length - 2) {
          const trigram = `${words[i]} ${words[i+1]} ${words[i+2]}`;
          if (!phraseDocMap.has(trigram)) phraseDocMap.set(trigram, new Set());
          phraseDocMap.get(trigram).add(post.id);
        }
      }
    }

    let candidates = Array.from(phraseDocMap.entries())
      .map(([tag, set]) => ({ tag, count: set.size }))
      .filter(e => e.count > 1 || e.tag.startsWith('#'));

    candidates.sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return b.tag.length - a.tag.length;
    });

    const finalTrends = [];
    for (const candidate of candidates) {
      let isRedundant = false;
      for (const accepted of finalTrends) {
        if (accepted.tag.includes(candidate.tag)) {
          isRedundant = true;
          break;
        }
      }
      if (!isRedundant) finalTrends.push(candidate);
      if (finalTrends.length >= 10) break;
    }

    res.json(finalTrends);
  } catch (err) {
    console.error('Trending error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/explore/discover
router.get('/discover', async (req, res) => {
  const pool = await getPool();
  try {
    const query = `
      SELECT p.*,
             u.name as user_name, u.avatar_icon_id as user_avatar_icon_id,
             u.avatar_hex as user_avatar_hex, u.profile_image_url as user_profile_image_url,
             u.department_code,
             (p.like_count * 2.0) + (p.comment_count * 3.0) +
             IF(TIMESTAMPDIFF(HOUR, p.created_at, NOW()) < 24, 20, 100.0 / (TIMESTAMPDIFF(HOUR, p.created_at, NOW()) + 5)) +
             IF(p.media_urls IS NOT NULL, 15.0, 0) AS score
      FROM posts p
      JOIN users u ON p.user_uid = u.uid
      WHERE p.user_uid != ? 
        AND p.user_uid NOT IN (SELECT following_uid FROM follows WHERE follower_uid = ?)
      ORDER BY score DESC LIMIT 50;
    `;
    const [rows] = await pool.execute(query, [req.uid, req.uid]);
    
    // Parse JSON
    rows.forEach(post => {
      if (post.media_urls && typeof post.media_urls === 'string') {
        post.media_urls = JSON.parse(post.media_urls);
      }
    });

    res.json(rows);
  } catch (err) {
    console.error('Discover error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/explore/recommended
router.get('/recommended', async (req, res) => {
  const pool = await getPool();
  try {
    // 1. Get user department
    const [users] = await pool.execute('SELECT department FROM users WHERE uid = ?', [req.uid]);
    const dept = users.length > 0 ? users[0].department : null;

    const deptKeywords = {
      'Teknik Sipil': ['beton', 'gedung', 'konstruksi', 'sipil'],
      'Teknik Mesin': ['mesin', 'energi', 'otomotif'],
      'Teknik Elektro': ['elektro', 'listrik', 'iot'],
      'Teknik Informatika & Komputer': ['coding', 'flutter', 'tik', 'komputer', 'program', 'bug'],
      'Akuntansi': ['akuntansi', 'keuangan', 'saham'],
      'Administrasi Niaga': ['bisnis', 'marketing', 'administrasi'],
      'Teknik Grafika & Penerbitan': ['desain', 'grafis', 'media'],
    };
    const interests = deptKeywords[dept] || [];
    const interestRegex = interests.length > 0 ? interests.join('|') : '$$$IMPOSSIBLE$$$';

    const query = `
      SELECT p.*,
             u.name as user_name, u.avatar_icon_id as user_avatar_icon_id,
             u.avatar_hex as user_avatar_hex, u.profile_image_url as user_profile_image_url,
             u.department_code,
             IF(f.following_uid IS NOT NULL, 50.0, 0.0) +
             IF(LOWER(p.text) REGEXP ?, 30.0, 0.0) +
             (80.0 / (TIMESTAMPDIFF(HOUR, p.created_at, NOW()) + 1)) AS score
      FROM posts p
      JOIN users u ON p.user_uid = u.uid
      LEFT JOIN follows f ON f.following_uid = p.user_uid AND f.follower_uid = ?
      WHERE p.user_uid != ?
      ORDER BY score DESC LIMIT 50;
    `;
    const [rows] = await pool.execute(query, [interestRegex, req.uid, req.uid]);

    rows.forEach(post => {
      if (post.media_urls && typeof post.media_urls === 'string') {
        post.media_urls = JSON.parse(post.media_urls);
      }
    });

    res.json(rows);
  } catch (err) {
    console.error('Recommended error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
