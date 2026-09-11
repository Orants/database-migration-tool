ALTER TABLE users ADD COLUMN country_code VARCHAR(2);
UPDATE users SET country_code = 'EE' WHERE country_code IS NULL;
ALTER TABLE users ALTER COLUMN country_code SET NOT NULL;