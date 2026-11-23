-- Seeds the first portal user on a fresh database volume.
-- Change this password before the first `docker compose up` (see SECURITY.md).
USE cyber_eye;

INSERT INTO users (username, email, password_hash)
VALUES ('admin', 'admin@cybereye.local', SHA2('ChangeMe-CyberEye', 256))
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);
