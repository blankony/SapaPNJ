const SEED_PREFIX = 'seed_explore_';
const DEFAULT_VIEWER_UID = `${SEED_PREFIX}viewer`;
const configuredViewerUid = process.env.SEED_VIEWER_UID?.trim();
const VIEWER_UID = configuredViewerUid || DEFAULT_VIEWER_UID;
const usesExternalViewer = VIEWER_UID !== DEFAULT_VIEWER_UID;

const seedViewerUser = {
  uid: DEFAULT_VIEWER_UID,
  email: 'seed.explore.viewer@sapapnj.test',
  name: 'Seed Explore Viewer',
  department: 'Teknik Informatika & Komputer',
  department_code: 'TIK',
};

const seedAuthorUsers = [
  {
    uid: `${SEED_PREFIX}followed_author`,
    email: 'seed.explore.followed@sapapnj.test',
    name: 'Seed Followed Author',
    department: 'Teknik Elektro',
    department_code: 'TE',
  },
  {
    uid: `${SEED_PREFIX}hot_author`,
    email: 'seed.explore.hot@sapapnj.test',
    name: 'Seed Hot Author',
    department: 'Teknik Informatika & Komputer',
    department_code: 'TIK',
  },
  {
    uid: `${SEED_PREFIX}media_author`,
    email: 'seed.explore.media@sapapnj.test',
    name: 'Seed Media Author',
    department: 'Administrasi Niaga',
    department_code: 'AN',
  },
  {
    uid: `${SEED_PREFIX}quiet_author`,
    email: 'seed.explore.quiet@sapapnj.test',
    name: 'Seed Quiet Author',
    department: 'Akuntansi',
    department_code: 'AK',
  },
  {
    uid: `${SEED_PREFIX}community_owner`,
    email: 'seed.explore.community@sapapnj.test',
    name: 'Seed Community Owner',
    department: 'Teknik Mesin',
    department_code: 'TM',
  },
  {
    uid: `${SEED_PREFIX}private_author`,
    email: 'seed.explore.private@sapapnj.test',
    name: 'Seed Private Author',
    department: 'Teknik Sipil',
    department_code: 'TS',
  },
];

const engagementUsers = Array.from({ length: 32 }, (_, index) => {
  const padded = String(index + 1).padStart(2, '0');
  return {
    uid: `${SEED_PREFIX}engager_${padded}`,
    email: `seed.explore.engager${padded}@sapapnj.test`,
    name: `Seed Engager ${padded}`,
    department: 'Teknik Informatika & Komputer',
    department_code: 'TIK',
  };
});

const users = [
  ...(usesExternalViewer ? [] : [seedViewerUser]),
  ...seedAuthorUsers,
  ...engagementUsers,
];

const communities = [
  {
    id: `${SEED_PREFIX}robotics`,
    name: 'Seed Robotics PNJ',
    description: 'Fixture community for explore and discovery feed testing.',
    owner_uid: `${SEED_PREFIX}community_owner`,
    category: 'casual',
    is_verified: true,
    allow_member_posts: true,
  },
];

const posts = [
  {
    id: `${SEED_PREFIX}post_hot_magang`,
    user_uid: `${SEED_PREFIX}hot_author`,
    text: 'Info magang PNJ minggu ini #magang #karier. Diskusi info magang dan beasiswa pnj untuk mahasiswa.',
    visibility: 'public',
    hoursAgo: 2,
    likeCount: 16,
    commentCount: 8,
  },
  {
    id: `${SEED_PREFIX}post_media_beasiswa`,
    user_uid: `${SEED_PREFIX}media_author`,
    text: 'Beasiswa PNJ dan info magang dibuka lagi #beasiswa #magang. Simpan jadwal uts biar tidak lupa.',
    visibility: 'public',
    media_urls: ['https://example.com/seed/beasiswa-pnj.jpg'],
    media_type: 'image',
    hoursAgo: 5,
    likeCount: 11,
    commentCount: 4,
  },
  {
    id: `${SEED_PREFIX}post_trend_uts_a`,
    user_uid: `${SEED_PREFIX}hot_author`,
    text: 'Jadwal uts teknik informatika sudah rilis #uts #krs. Cek jadwal uts masing-masing kelas.',
    visibility: 'public',
    hoursAgo: 8,
    likeCount: 4,
    commentCount: 1,
  },
  {
    id: `${SEED_PREFIX}post_trend_uts_b`,
    user_uid: `${SEED_PREFIX}quiet_author`,
    text: 'Jadwal uts kampus dan pengisian krs perlu dicek ulang #uts #krs.',
    visibility: 'public',
    hoursAgo: 11,
    likeCount: 2,
    commentCount: 0,
  },
  {
    id: `${SEED_PREFIX}post_followed_hot`,
    user_uid: `${SEED_PREFIX}followed_author`,
    text: 'Jadwal uts elektro ramai dibahas #uts #krs. Post ini harus masuk trending tapi keluar dari discovery viewer.',
    visibility: 'public',
    hoursAgo: 4,
    likeCount: 22,
    commentCount: 11,
  },
  {
    id: `${SEED_PREFIX}post_community_robotics`,
    user_uid: `${SEED_PREFIX}community_owner`,
    text: 'Komunitas robotika PNJ buka latihan sensor dan iot #robotika #iot. Info magang robotika juga dibahas.',
    visibility: 'public',
    community_id: `${SEED_PREFIX}robotics`,
    is_community_identity: true,
    media_urls: ['https://example.com/seed/robotics-lab.jpg'],
    media_type: 'image',
    hoursAgo: 1,
    likeCount: 14,
    commentCount: 6,
  },
  {
    id: `${SEED_PREFIX}post_viewer_own`,
    user_uid: VIEWER_UID,
    text: 'Post milik viewer dengan skor tinggi #vieweronly. Ini harus keluar dari discovery viewer.',
    visibility: 'public',
    hoursAgo: 1,
    likeCount: 30,
    commentCount: 20,
  },
  {
    id: `${SEED_PREFIX}post_private`,
    user_uid: `${SEED_PREFIX}private_author`,
    text: 'Catatan privat seed discovery. Post private ini tidak boleh terlihat oleh viewer.',
    visibility: 'private',
    hoursAgo: 3,
    likeCount: 28,
    commentCount: 12,
  },
  {
    id: `${SEED_PREFIX}post_followers_only`,
    user_uid: `${SEED_PREFIX}quiet_author`,
    text: 'Catatan followers-only seed discovery. Viewer tidak mengikuti author ini.',
    visibility: 'followers',
    hoursAgo: 3,
    likeCount: 21,
    commentCount: 7,
  },
  {
    id: `${SEED_PREFIX}post_oldtrend_a`,
    user_uid: `${SEED_PREFIX}hot_author`,
    text: 'Topik lama yang tidak boleh masuk trending #oldtrend #arsip.',
    visibility: 'public',
    hoursAgo: 240,
    likeCount: 18,
    commentCount: 5,
  },
  {
    id: `${SEED_PREFIX}post_oldtrend_b`,
    user_uid: `${SEED_PREFIX}media_author`,
    text: 'Topik lama kedua yang tidak boleh masuk trending #oldtrend #arsip.',
    visibility: 'public',
    hoursAgo: 260,
    likeCount: 17,
    commentCount: 4,
  },
];

const stopWords = new Set([
  'the', 'and', 'is', 'to', 'in', 'of', 'for', 'on', 'at', 'this',
  'di', 'dan', 'yang', 'ini', 'itu', 'ke', 'dari', 'ada', 'dengan',
  'untuk', 'yg', 'gak', 'ya', 'aja', 'si', 'saya', 'aku', 'bisa', 'mau',
  'banget', 'sama', 'sudah', 'lagi', 'apa', 'kapan', 'dimana',
]);

function assertSeedEnabled() {
  if (process.env.ALLOW_DEV_SEED === '1') return;

  throw new Error(
    'Refusing to seed without ALLOW_DEV_SEED=1. This script writes fixture data to the configured database.'
  );
}

function assertDatabaseEnv() {
  const requiredEnv = [
    'INSTANCE_CONNECTION_NAME',
    'DB_USER',
    'DB_PASS',
    'DB_NAME',
  ];
  const missingEnv = requiredEnv.filter((key) => !process.env[key]?.trim());

  if (missingEnv.length === 0) return;

  throw new Error(
    [
      'Missing Cloud SQL environment variables for the explore seed fixture:',
      '',
      ...missingEnv.map((key) => `  - ${key}`),
      '',
      'Export them before running the script. Example:',
      '',
      '  export INSTANCE_CONNECTION_NAME="sapapnj-gcp:asia-southeast2:sapapnj-db"',
      '  export DB_USER="sapapnj-api"',
      '  export DB_PASS="your-db-password"',
      '  export DB_NAME="sapapnj"',
      '  ALLOW_DEV_SEED=1 npm run seed:explore',
      '',
      'The instance connection name format is PROJECT:REGION:INSTANCE.',
    ].join('\n')
  );
}

function getDatabaseTools() {
  try {
    return require('../db');
  } catch (error) {
    if (error.code === 'MODULE_NOT_FOUND') {
      throw new Error(
        [
          'Missing API npm dependencies. Install them before running the seed fixture:',
          '',
          '  cd cloud_functions/api',
          '  npm install',
          '',
          'This error happens before the script connects to Cloud SQL.',
        ].join('\n')
      );
    }

    throw error;
  }
}

function formatRuntimeError(error) {
  const message = error?.message || String(error);

  if (error?.code === 'ER_ACCESS_DENIED_ERROR' || message.includes('Access denied for user')) {
    return [
      message,
      '',
      'Cloud SQL was reached, but MySQL rejected the login.',
      '',
      'Check these values in the same shell running the seed command:',
      '',
      '  echo "$INSTANCE_CONNECTION_NAME"',
      '  echo "$DB_USER"',
      '  echo "$DB_NAME"',
      '',
      'Then verify the password and MySQL user host in Cloud SQL:',
      '',
      '  gcloud sql users list --instance=sapapnj-db',
      '  gcloud sql users set-password sapapnj-api --instance=sapapnj-db --password="your-db-password"',
      '',
      'If the user is host-restricted, ensure there is a sapapnj-api user for host "%".',
    ].join('\n');
  }

  return message;
}

async function assertDatabaseConnection(pool) {
  await pool.execute('SELECT 1');
}

async function cleanupSeedData(pool) {
  await pool.execute(
    `DELETE FROM notifications
     WHERE id LIKE ?
        OR user_uid LIKE ?
        OR sender_uid LIKE ?
        OR post_id LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`, `${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM bookmarks
     WHERE user_uid LIKE ? OR post_id LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM post_likes
     WHERE user_uid LIKE ? OR post_id LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM comments
     WHERE id LIKE ? OR user_uid LIKE ? OR post_id LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM posts
     WHERE id LIKE ? OR user_uid LIKE ? OR original_post_id LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM community_members
     WHERE community_id LIKE ? OR user_uid LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM follow_requests
     WHERE sender_uid LIKE ? OR target_uid LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM follows
     WHERE follower_uid LIKE ? OR following_uid LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM communities
     WHERE id LIKE ? OR owner_uid LIKE ?`,
    [`${SEED_PREFIX}%`, `${SEED_PREFIX}%`]
  );
  await pool.execute(
    `DELETE FROM chat_messages
     WHERE session_id IN (SELECT id FROM chat_sessions WHERE user_uid LIKE ?)`,
    [`${SEED_PREFIX}%`]
  );
  await pool.execute(
    'DELETE FROM chat_sessions WHERE user_uid LIKE ?',
    [`${SEED_PREFIX}%`]
  );
  await pool.execute('DELETE FROM users WHERE uid LIKE ?', [`${SEED_PREFIX}%`]);
}

async function assertViewerExists(pool) {
  if (!usesExternalViewer) return;

  const [rows] = await pool.execute('SELECT uid FROM users WHERE uid = ?', [VIEWER_UID]);
  if (rows.length > 0) return;

  throw new Error(
    `SEED_VIEWER_UID=${VIEWER_UID} does not exist in users. Use an existing SQL user uid or omit SEED_VIEWER_UID.`
  );
}

async function seedUsers(pool) {
  for (const user of users) {
    await pool.execute(
      `INSERT INTO users (
        uid, email, name, bio, department, department_code,
        verification_status, agreed_to_terms, agreed_at, created_at
      )
      VALUES (?, ?, ?, 'Seed fixture account for explore testing.', ?, ?, 'verified', TRUE, NOW(), NOW())
      ON DUPLICATE KEY UPDATE
        email = VALUES(email),
        name = VALUES(name),
        department = VALUES(department),
        department_code = VALUES(department_code),
        verification_status = VALUES(verification_status),
        agreed_to_terms = VALUES(agreed_to_terms)`,
      [
        user.uid,
        user.email,
        user.name,
        user.department,
        user.department_code,
      ]
    );
  }
}

async function seedCommunities(pool) {
  for (const community of communities) {
    await pool.execute(
      `INSERT INTO communities (
        id, name, description, category, owner_uid, is_verified,
        allow_member_posts, created_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        description = VALUES(description),
        category = VALUES(category),
        owner_uid = VALUES(owner_uid),
        is_verified = VALUES(is_verified),
        allow_member_posts = VALUES(allow_member_posts)`,
      [
        community.id,
        community.name,
        community.description,
        community.category,
        community.owner_uid,
        community.is_verified,
        community.allow_member_posts,
      ]
    );

    await pool.execute(
      `INSERT INTO community_members (community_id, user_uid, role, created_at)
       VALUES (?, ?, 'admin', NOW())
       ON DUPLICATE KEY UPDATE role = VALUES(role)`,
      [community.id, community.owner_uid]
    );
  }
}

async function seedFollows(pool) {
  await pool.execute(
    `INSERT INTO follows (follower_uid, following_uid, created_at)
     VALUES (?, ?, NOW())
     ON DUPLICATE KEY UPDATE created_at = VALUES(created_at)`,
    [VIEWER_UID, `${SEED_PREFIX}followed_author`]
  );
}

async function seedPosts(pool) {
  for (const post of posts) {
    await pool.execute(
      `INSERT INTO posts (
        id, user_uid, text, media_urls, media_type, visibility, community_id,
        is_community_identity, is_repost, original_post_id, like_count,
        comment_count, repost_count, created_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, FALSE, NULL, ?, ?, 0, DATE_SUB(NOW(), INTERVAL ${post.hoursAgo} HOUR))
      ON DUPLICATE KEY UPDATE
        user_uid = VALUES(user_uid),
        text = VALUES(text),
        media_urls = VALUES(media_urls),
        media_type = VALUES(media_type),
        visibility = VALUES(visibility),
        community_id = VALUES(community_id),
        is_community_identity = VALUES(is_community_identity),
        like_count = VALUES(like_count),
        comment_count = VALUES(comment_count),
        created_at = VALUES(created_at)`,
      [
        post.id,
        post.user_uid,
        post.text,
        post.media_urls ? JSON.stringify(post.media_urls) : null,
        post.media_type || null,
        post.visibility,
        post.community_id || null,
        post.is_community_identity || false,
        post.likeCount,
        post.commentCount,
      ]
    );
  }
}

async function seedLikesAndComments(pool) {
  const engagers = engagementUsers.map((user) => user.uid);
  let commentSerial = 1;

  for (const post of posts) {
    for (let index = 0; index < post.likeCount; index++) {
      await pool.execute(
        `INSERT INTO post_likes (post_id, user_uid, created_at)
         VALUES (?, ?, NOW())
         ON DUPLICATE KEY UPDATE created_at = VALUES(created_at)`,
        [post.id, engagers[index % engagers.length]]
      );
    }

    for (let index = 0; index < post.commentCount; index++) {
      const padded = String(index + 1).padStart(2, '0');
      const commentId = `${SEED_PREFIX}comment_${String(commentSerial).padStart(4, '0')}`;
      commentSerial += 1;

      await pool.execute(
        `INSERT INTO comments (id, post_id, user_uid, text, created_at)
         VALUES (?, ?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE
           user_uid = VALUES(user_uid),
           text = VALUES(text),
           created_at = VALUES(created_at)`,
        [
          commentId,
          post.id,
          engagers[(index + 3) % engagers.length],
          `Seed comment ${padded} for ${post.id}`,
        ]
      );
    }
  }

  await pool.execute(
    `UPDATE posts p
     SET like_count = (
       SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id
     ),
     comment_count = (
       SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id
     )
     WHERE p.id LIKE ?`,
    [`${SEED_PREFIX}%`]
  );
}

function buildTrendingPreview(recentPosts) {
  const phraseDocMap = new Map();

  for (const post of recentPosts) {
    if (!post.text) continue;

    const cleanText = post.text.toLowerCase().replace(/[^\w\s#]/g, '');
    const words = cleanText.split(/\s+/).filter((word) => word.length > 0);

    for (let index = 0; index < words.length; index++) {
      if (words[index].startsWith('#')) {
        if (!phraseDocMap.has(words[index])) phraseDocMap.set(words[index], new Set());
        phraseDocMap.get(words[index]).add(post.id);
      }

      if (index < words.length - 1) {
        if (!stopWords.has(words[index]) && !stopWords.has(words[index + 1])) {
          const bigram = `${words[index]} ${words[index + 1]}`;
          if (!phraseDocMap.has(bigram)) phraseDocMap.set(bigram, new Set());
          phraseDocMap.get(bigram).add(post.id);
        }
      }

      if (index < words.length - 2) {
        const trigram = `${words[index]} ${words[index + 1]} ${words[index + 2]}`;
        if (!phraseDocMap.has(trigram)) phraseDocMap.set(trigram, new Set());
        phraseDocMap.get(trigram).add(post.id);
      }
    }
  }

  const candidates = Array.from(phraseDocMap.entries())
    .map(([tag, set]) => ({ tag, count: set.size }))
    .filter((entry) => entry.count > 1 || entry.tag.startsWith('#'))
    .sort((a, b) => {
      if (b.count !== a.count) return b.count - a.count;
      return b.tag.length - a.tag.length;
    });

  const finalTrends = [];
  for (const candidate of candidates) {
    const isRedundant = finalTrends.some((accepted) => accepted.tag.includes(candidate.tag));
    if (!isRedundant) finalTrends.push(candidate);
    if (finalTrends.length >= 10) break;
  }

  return finalTrends;
}

async function printVerificationPreview(pool) {
  const [recentPosts] = await pool.execute(
    `SELECT id, text
     FROM posts
     WHERE id LIKE ? AND created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)`,
    [`${SEED_PREFIX}%`]
  );
  const trendingPreview = buildTrendingPreview(recentPosts);

  const [discoverPreview] = await pool.execute(
    `SELECT p.id,
            p.user_uid,
            p.visibility,
            c.name as community_name,
            (
              (p.like_count * 2.0) +
              (p.comment_count * 3.0) +
              IF(TIMESTAMPDIFF(HOUR, p.created_at, NOW()) < 24, 20, 100.0 / (TIMESTAMPDIFF(HOUR, p.created_at, NOW()) + 5)) +
              IF(p.media_urls IS NOT NULL, 15.0, 0)
            ) AS score
     FROM posts p
     LEFT JOIN communities c ON p.community_id = c.id
     WHERE p.id LIKE ?
       AND p.user_uid != ?
       AND (
         p.visibility = 'public'
         OR (
           p.visibility = 'followers'
           AND (
             p.user_uid = ?
             OR EXISTS (
               SELECT 1 FROM follows
               WHERE follower_uid = ? AND following_uid = p.user_uid
             )
           )
         )
         OR (p.visibility = 'private' AND p.user_uid = ?)
       )
       AND p.user_uid NOT IN (
         SELECT following_uid FROM follows WHERE follower_uid = ?
       )
     ORDER BY score DESC
     LIMIT 10`,
    [
      `${SEED_PREFIX}%`,
      VIEWER_UID,
      VIEWER_UID,
      VIEWER_UID,
      VIEWER_UID,
      VIEWER_UID,
    ]
  );

  const [excludedPreview] = await pool.execute(
    `SELECT id, user_uid, visibility
     FROM posts
     WHERE id IN (?, ?, ?, ?)`,
    [
      `${SEED_PREFIX}post_followed_hot`,
      `${SEED_PREFIX}post_viewer_own`,
      `${SEED_PREFIX}post_private`,
      `${SEED_PREFIX}post_followers_only`,
    ]
  );

  console.log('\nSeeded explore fixture data.');
  const viewerMode = usesExternalViewer ? 'configured existing user' : 'seeded fixture user';
  console.log(`Viewer UID: ${VIEWER_UID} (${viewerMode})`);
  console.log('\nTrending preview from seeded recent posts:');
  for (const trend of trendingPreview) {
    console.log(`- ${trend.tag}: ${trend.count}`);
  }

  console.log('\nDiscovery preview for the viewer:');
  for (const post of discoverPreview) {
    const community = post.community_name ? ` community="${post.community_name}"` : '';
    console.log(`- ${post.id} score=${Number(post.score).toFixed(2)}${community}`);
  }

  console.log('\nNegative-control posts seeded for exclusion checks:');
  for (const post of excludedPreview) {
    console.log(`- ${post.id} author=${post.user_uid} visibility=${post.visibility}`);
  }
}

async function main() {
  assertSeedEnabled();
  assertDatabaseEnv();

  const { getPool, closePool } = getDatabaseTools();
  const cleanupOnly = process.argv.includes('--cleanup');
  let pool;

  try {
    pool = await getPool();
    await assertDatabaseConnection(pool);
    await cleanupSeedData(pool);
    if (cleanupOnly) {
      console.log('Removed explore seed fixture data.');
      return;
    }

    await assertViewerExists(pool);
    await seedUsers(pool);
    await seedCommunities(pool);
    await seedFollows(pool);
    await seedPosts(pool);
    await seedLikesAndComments(pool);
    await printVerificationPreview(pool);
  } finally {
    await closePool();
  }
}

main().catch((error) => {
  console.error(formatRuntimeError(error));
  process.exitCode = 1;
});
