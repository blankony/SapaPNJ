-- ============================================================================
-- SAPA PNJ — MySQL Schema (Phase 2: Database Migration)
-- ============================================================================

-- Users (Firebase Auth UID is the primary key)
CREATE TABLE users (
  uid                 VARCHAR(128) PRIMARY KEY,
  email               VARCHAR(255) NOT NULL UNIQUE,
  name                VARCHAR(100) NOT NULL,
  nim                 VARCHAR(18) UNIQUE,
  bio                 VARCHAR(500) DEFAULT 'Member of PNJ',
  department          VARCHAR(100),
  study_program       VARCHAR(100),
  department_code     VARCHAR(20),
  avatar_icon_id      INT DEFAULT 0,
  avatar_hex          VARCHAR(10) DEFAULT '',
  profile_image_url   TEXT,
  banner_image_url    TEXT,
  is_private          BOOLEAN DEFAULT FALSE,
  pinned_post_id      VARCHAR(36),
  verification_status ENUM('none','pending','verified') DEFAULT 'none',
  agreed_to_terms     BOOLEAN DEFAULT FALSE,
  agreed_at           DATETIME,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Follow relationships (replaces followers[] and following[] arrays)
CREATE TABLE follows (
  follower_uid  VARCHAR(128) NOT NULL,
  following_uid VARCHAR(128) NOT NULL,
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_uid, following_uid),
  FOREIGN KEY (follower_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (following_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX idx_follows_following ON follows(following_uid);

-- Follow requests (for private accounts)
CREATE TABLE follow_requests (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  sender_uid VARCHAR(128) NOT NULL,
  target_uid VARCHAR(128) NOT NULL,
  status     ENUM('pending','accepted','rejected') DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_follow_request (sender_uid, target_uid),
  FOREIGN KEY (sender_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (target_uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- Communities
CREATE TABLE communities (
  id                   VARCHAR(36) PRIMARY KEY,
  name                 VARCHAR(100) NOT NULL,
  description          TEXT,
  category             ENUM('casual','partner_official','pnj_official') DEFAULT 'casual',
  image_url            TEXT,
  banner_image_url     TEXT,
  owner_uid            VARCHAR(128) NOT NULL,
  is_verified          BOOLEAN DEFAULT FALSE,
  verification_doc_url TEXT,
  allow_member_posts   BOOLEAN DEFAULT FALSE,
  created_at           DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- Community members (replaces admins[], editors[], moderators[], followers[] arrays)
CREATE TABLE community_members (
  community_id VARCHAR(36) NOT NULL,
  user_uid     VARCHAR(128) NOT NULL,
  role         ENUM('follower','admin','editor','moderator') DEFAULT 'follower',
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (community_id, user_uid),
  FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- Posts
CREATE TABLE posts (
  id                    VARCHAR(36) PRIMARY KEY,
  user_uid              VARCHAR(128) NOT NULL,
  text                  TEXT,
  media_urls            JSON,
  media_type            VARCHAR(10),
  visibility            ENUM('public','followers','private') DEFAULT 'public',
  community_id          VARCHAR(36),
  is_community_identity BOOLEAN DEFAULT FALSE,
  is_repost             BOOLEAN DEFAULT FALSE,
  original_post_id      VARCHAR(36),
  like_count            INT DEFAULT 0,
  comment_count         INT DEFAULT 0,
  repost_count          INT DEFAULT 0,
  created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE SET NULL
);

CREATE INDEX idx_posts_user ON posts(user_uid);
CREATE INDEX idx_posts_community ON posts(community_id);
CREATE INDEX idx_posts_timestamp ON posts(created_at DESC);

-- Post likes (replaces likes[] array)
CREATE TABLE post_likes (
  post_id    VARCHAR(36) NOT NULL,
  user_uid   VARCHAR(128) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_uid),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- Comments (replaces posts/{id}/comments subcollection)
CREATE TABLE comments (
  id         VARCHAR(36) PRIMARY KEY,
  post_id    VARCHAR(36) NOT NULL,
  user_uid   VARCHAR(128) NOT NULL,
  text       TEXT,
  media_url  TEXT,
  media_type VARCHAR(10),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX idx_comments_post ON comments(post_id, created_at);

-- Bookmarks (replaces users/{uid}/bookmarks subcollection)
CREATE TABLE bookmarks (
  user_uid   VARCHAR(128) NOT NULL,
  post_id    VARCHAR(36) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_uid, post_id),
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

-- Notifications (replaces users/{uid}/notifications subcollection)
CREATE TABLE notifications (
  id                VARCHAR(36) PRIMARY KEY,
  user_uid          VARCHAR(128) NOT NULL,
  sender_uid        VARCHAR(128),
  type              VARCHAR(30) NOT NULL,
  post_id           VARCHAR(36),
  post_text_snippet VARCHAR(100),
  is_read           BOOLEAN DEFAULT FALSE,
  created_at        DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX idx_notifications_user ON notifications(user_uid, created_at DESC);

-- Blocked users (replaces users/{uid}/moderation/blocked subcollection)
CREATE TABLE blocked_users (
  blocker_uid VARCHAR(128) NOT NULL,
  blocked_uid VARCHAR(128) NOT NULL,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (blocker_uid, blocked_uid),
  FOREIGN KEY (blocker_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (blocked_uid) REFERENCES users(uid) ON DELETE CASCADE
);

-- AI Chat sessions (replaces users/{uid}/chat_sessions subcollection)
CREATE TABLE chat_sessions (
  id           VARCHAR(36) PRIMARY KEY,
  user_uid     VARCHAR(128) NOT NULL,
  title        VARCHAR(200) DEFAULT 'New Conversation',
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX idx_chat_sessions_user ON chat_sessions(user_uid, last_updated DESC);

-- AI Chat messages (replaces users/{uid}/chat_sessions/{sessionId}/messages subcollection)
CREATE TABLE chat_messages (
  id           VARCHAR(36) PRIMARY KEY,
  session_id   VARCHAR(36) NOT NULL,
  text         TEXT NOT NULL,
  is_user      BOOLEAN NOT NULL,
  timestamp    DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_chat_messages_session ON chat_messages(session_id, timestamp ASC);
