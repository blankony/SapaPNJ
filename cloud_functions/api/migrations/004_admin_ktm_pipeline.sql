-- Migration 004: Admin KTM Verification Pipeline
-- Adds role system, ktm_image_url, and 'rejected' verification status

ALTER TABLE users ADD COLUMN role ENUM('user','admin') DEFAULT 'user' AFTER pinned_post_id;
ALTER TABLE users ADD COLUMN ktm_image_url TEXT AFTER verification_status;
ALTER TABLE users MODIFY COLUMN verification_status ENUM('none','pending','verified','rejected') DEFAULT 'none';

-- Set initial admin
UPDATE users SET role = 'admin' WHERE email = 'arnold.holyridho.runtuwene.te23@stu.pnj.ac.id';
