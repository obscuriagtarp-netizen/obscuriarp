CREATE TABLE IF NOT EXISTS `ob_properties` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `property_key` VARCHAR(64) NOT NULL,
    `type` ENUM('apartment', 'house') NOT NULL DEFAULT 'house',
    `ownership_mode` ENUM('unique', 'instanced') NOT NULL DEFAULT 'unique',
    `label` VARCHAR(80) NOT NULL,
    `description` VARCHAR(500) NOT NULL DEFAULT '',
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `payment_account` VARCHAR(20) NOT NULL DEFAULT 'bank',
    `purchasable` TINYINT(1) NOT NULL DEFAULT 1,
    `is_starter` TINYINT(1) NOT NULL DEFAULT 0,
    `is_listed` TINYINT(1) NOT NULL DEFAULT 1,
    `status` ENUM('available', 'disabled') NOT NULL DEFAULT 'available',
    `vip_tier` VARCHAR(40) DEFAULT NULL,
    `preset_key` VARCHAR(64) NOT NULL,
    `entrance` LONGTEXT NOT NULL,
    `interior` LONGTEXT NOT NULL,
    `gallery` LONGTEXT DEFAULT NULL,
    `stash_slots` SMALLINT UNSIGNED NOT NULL DEFAULT 30,
    `stash_weight` INT UNSIGNED NOT NULL DEFAULT 50000,
    `created_by` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ux_ob_properties_key` (`property_key`),
    KEY `ix_ob_properties_catalog` (`status`, `is_listed`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_property_ownerships` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `property_id` INT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `acquisition` VARCHAR(24) NOT NULL DEFAULT 'admin',
    `expires_at` BIGINT DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ux_ob_property_owner` (`property_id`, `citizenid`),
    KEY `ix_ob_property_owner_citizen` (`citizenid`, `expires_at`),
    KEY `ix_ob_property_owner_property` (`property_id`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_property_access` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ownership_id` BIGINT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `role` ENUM('resident', 'guest') NOT NULL DEFAULT 'resident',
    `granted_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ux_ob_property_access` (`ownership_id`, `citizenid`),
    KEY `ix_ob_property_access_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_property_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor` VARCHAR(64) NOT NULL,
    `action` VARCHAR(48) NOT NULL,
    `property_id` INT UNSIGNED DEFAULT NULL,
    `target_citizenid` VARCHAR(64) DEFAULT NULL,
    `details` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `ix_ob_property_audit_property` (`property_id`, `created_at`),
    KEY `ix_ob_property_audit_target` (`target_citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

