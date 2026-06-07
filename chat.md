# Agent Task Queue

This file is used to communicate tasks between agents. Each task is a standalone unit of work. Follow the [Commit Rules](documents/COMMIT_RULES.md) for all commits.

---

## Task 001 — Fix: Recommended & Discover tab posts render without profile picture and show `@user` handle

**Status:** `OPEN`
**Priority:** High
**Reported:** 2026-06-07

### Bug Description

Posts displayed in the **Recommended** tab (home feed) and the **Discover** section (search page) render incorrectly:
- Profile picture / avatar is missing (falls back to default icon).
- The handle displays as `@user` instead of the user's actual email handle.
- The display name renders correctly.

### Root Cause

The backend SQL queries in [`cloud_functions/api/routes/explore.js`](cloud_functions/api/routes/explore.js) for the `/api/explore/discover` (line 117) and `/api/explore/recommended` (line 163) endpoints are **missing the community JOIN and several user column aliases** that the main feed query in [`cloud_functions/api/routes/posts.js`](cloud_functions/api/routes/posts.js) includes.

**What the main feed query (`posts.js`) returns:**
```sql
SELECT p.*, u.name as user_name, u.email as user_email,
       u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
       c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified
FROM posts p
JOIN users u ON p.user_uid = u.uid
LEFT JOIN communities c ON p.community_id = c.id
```

**What the discover/recommended queries (`explore.js`) return:**
```sql
SELECT p.*,
       u.name as user_name, u.email as user_email,
       u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
       u.name as user_name, u.avatar_icon_id as user_avatar_icon_id,
       u.avatar_hex as user_avatar_hex, u.profile_image_url as user_profile_image_url,
       u.department_code,
       ...
FROM posts p
JOIN users u ON p.user_uid = u.uid
```

**Key differences causing the bug:**
1. The `explore.js` queries have **duplicate column aliases** (e.g., `u.name as user_name` appears twice), which is harmless but messy.
2. `explore.js` aliases some fields differently: `user_avatar_icon_id`, `user_avatar_hex`, `user_profile_image_url` — the Flutter client in [`lib/widgets/blog_post_card/post_header.dart`](lib/widgets/blog_post_card/post_header.dart) does NOT check for these prefixed field names. It expects `avatar_icon_id`, `avatar_hex`, `profile_image_url` (lines 97-105).
3. The `explore.js` queries are **missing the community LEFT JOIN**, so community-related fields (`community_name`, `community_image_url`, `community_verified`) will be `null`.

### Fix Instructions

**File to edit:** `cloud_functions/api/routes/explore.js`

Replace the SELECT columns in both the `/discover` query (line 117-132) and the `/recommended` query (line 163-177) to match the main feed format from `posts.js`. Specifically:

1. Remove the duplicate/prefixed aliases (`user_avatar_icon_id`, `user_avatar_hex`, `user_profile_image_url`, duplicate `user_name`).
2. Add the community LEFT JOIN and its columns.
3. Keep the custom scoring logic intact.

**For the `/discover` endpoint (line 117-132), replace with:**
```sql
SELECT p.*,
       u.name as user_name, u.email as user_email,
       u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
       u.department_code,
       c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified,
       (p.like_count * 2.0) + (p.comment_count * 3.0) +
       IF(TIMESTAMPDIFF(HOUR, p.created_at, NOW()) < 24, 20, 100.0 / (TIMESTAMPDIFF(HOUR, p.created_at, NOW()) + 5)) +
       IF(p.media_urls IS NOT NULL, 15.0, 0) AS score
FROM posts p
JOIN users u ON p.user_uid = u.uid
LEFT JOIN communities c ON p.community_id = c.id
WHERE p.user_uid != ?
  AND p.is_repost = FALSE
  AND p.user_uid NOT IN (SELECT following_uid FROM follows WHERE follower_uid = ?)
ORDER BY score DESC LIMIT 50;
```

**For the `/recommended` endpoint (line 163-177), replace with:**
```sql
SELECT p.*,
       u.name as user_name, u.email as user_email,
       u.avatar_icon_id, u.avatar_hex, u.profile_image_url,
       u.department_code,
       c.name as community_name, c.image_url as community_image_url, c.is_verified as community_verified,
       IF(f.following_uid IS NOT NULL, 50.0, 0.0) +
       IF(LOWER(p.text) REGEXP ?, 30.0, 0.0) +
       (80.0 / (TIMESTAMPDIFF(HOUR, p.created_at, NOW()) + 1)) AS score
FROM posts p
JOIN users u ON p.user_uid = u.uid
LEFT JOIN communities c ON p.community_id = c.id
LEFT JOIN follows f ON f.following_uid = p.user_uid AND f.follower_uid = ?
WHERE p.user_uid != ? AND p.is_repost = FALSE
ORDER BY score DESC LIMIT 50;
```

### Verification

After deploying the updated `explore.js`:
1. Open the app → Home → Recommended tab. Posts should show profile pictures and correct `@handle`.
2. Open Search → Discover section. Same verification.
3. Ensure community posts in these feeds display community name and icon correctly.

### Files Involved
| File | Role |
|------|------|
| [`cloud_functions/api/routes/explore.js`](cloud_functions/api/routes/explore.js) | **Backend — needs fix** |
| [`cloud_functions/api/routes/posts.js`](cloud_functions/api/routes/posts.js) | Reference — correct query format |
| [`lib/widgets/blog_post_card/post_header.dart`](lib/widgets/blog_post_card/post_header.dart) | Client — expected field names (lines 97-105, 211-213) |

### Commit Message
```
fix(explore): align discover and recommended SQL queries with main feed column aliases

- Removed duplicate/prefixed user column aliases (user_avatar_icon_id, etc.) that the Flutter client doesn't recognize.
- Added missing community LEFT JOIN to populate community_name, community_image_url, and community_verified.
- Ensures posts in Recommended and Discover tabs render with correct profile pictures and @handles.
```
