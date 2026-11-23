USE cyber_eye;

DELIMITER $$

CREATE TRIGGER users_bi_hash_password
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
  IF NEW.password_hash IS NOT NULL
     AND NEW.password_hash NOT REGEXP '^[0-9a-fA-F]{64}$' THEN
    SET NEW.password_hash = SHA2(NEW.password_hash, 256);
  END IF;
END$$

CREATE TRIGGER users_bu_hash_password
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
  IF NEW.password_hash IS NOT NULL
     AND NEW.password_hash NOT REGEXP '^[0-9a-fA-F]{64}$' THEN
    SET NEW.password_hash = SHA2(NEW.password_hash, 256);
  END IF;
END$$

DELIMITER ;
