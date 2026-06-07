ALTER TABLE users ADD COLUMN ktm_rejection_count INT DEFAULT 0 AFTER ktm_image_url;
ALTER TABLE users ADD COLUMN ktm_last_rejected_at DATETIME AFTER ktm_rejection_count;
