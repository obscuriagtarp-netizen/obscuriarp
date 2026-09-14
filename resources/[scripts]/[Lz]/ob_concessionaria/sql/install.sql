CREATE TABLE IF NOT EXISTS `vg_dealership_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership` VARCHAR(40) NOT NULL,
  `category` VARCHAR(40) NOT NULL,
  `model` VARCHAR(80) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `brand` VARCHAR(80) DEFAULT NULL,
  `price` BIGINT NOT NULL DEFAULT 0,
  `stock` INT NOT NULL DEFAULT 0,
  `purchase_type` VARCHAR(20) NOT NULL DEFAULT 'permanent',
  `duration_days` INT DEFAULT NULL,
  `image` TEXT DEFAULT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `display_order` INT NOT NULL DEFAULT 0,
  `metadata` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_dealership_model` (`dealership`, `model`),
  KEY `idx_dealership_category` (`dealership`, `category`),
  KEY `idx_enabled_stock` (`enabled`, `stock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `vg_dealership_vehicles`
  MODIFY COLUMN `price` BIGINT NOT NULL DEFAULT 0;

ALTER TABLE `vg_dealership_vehicles`
  ADD COLUMN IF NOT EXISTS `purchase_type` VARCHAR(20) NOT NULL DEFAULT 'permanent' AFTER `stock`;

ALTER TABLE `vg_dealership_vehicles`
  ADD COLUMN IF NOT EXISTS `duration_days` INT DEFAULT NULL AFTER `purchase_type`;

ALTER TABLE `vg_dealership_vehicles`
  MODIFY COLUMN `image` TEXT DEFAULT NULL;

CREATE TABLE IF NOT EXISTS `vg_dealership_sales` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` VARCHAR(64) NOT NULL,
  `dealership` VARCHAR(40) NOT NULL,
  `model` VARCHAR(80) NOT NULL,
  `plate` VARCHAR(16) NOT NULL,
  `currency` VARCHAR(20) NOT NULL,
  `purchase_type` VARCHAR(20) NOT NULL DEFAULT 'permanent',
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `base_price` BIGINT NOT NULL DEFAULT 0,
  `discount_amount` BIGINT NOT NULL DEFAULT 0,
  `discount_percent` DECIMAL(5,2) NOT NULL DEFAULT 0,
  `tax_amount` BIGINT NOT NULL DEFAULT 0,
  `total_price` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`),
  KEY `idx_dealership` (`dealership`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `vg_dealership_sales`
  MODIFY COLUMN `base_price` BIGINT NOT NULL DEFAULT 0;

ALTER TABLE `vg_dealership_sales`
  MODIFY COLUMN `tax_amount` BIGINT NOT NULL DEFAULT 0;

ALTER TABLE `vg_dealership_sales`
  MODIFY COLUMN `total_price` BIGINT NOT NULL DEFAULT 0;

ALTER TABLE `vg_dealership_sales`
  ADD COLUMN IF NOT EXISTS `purchase_type` VARCHAR(20) NOT NULL DEFAULT 'permanent' AFTER `currency`;

ALTER TABLE `vg_dealership_sales`
  ADD COLUMN IF NOT EXISTS `expires_at` TIMESTAMP NULL DEFAULT NULL AFTER `purchase_type`;

ALTER TABLE `vg_dealership_sales`
  ADD COLUMN IF NOT EXISTS `discount_amount` BIGINT NOT NULL DEFAULT 0 AFTER `base_price`;

ALTER TABLE `vg_dealership_sales`
  ADD COLUMN IF NOT EXISTS `discount_percent` DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER `discount_amount`;
