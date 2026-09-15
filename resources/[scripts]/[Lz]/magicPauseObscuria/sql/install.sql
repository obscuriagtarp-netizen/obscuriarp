CREATE TABLE IF NOT EXISTS `playtime` (
  `passport` VARCHAR(80) NOT NULL,
  `total_seconds` INT NOT NULL DEFAULT 0,
  `last_join_ts` BIGINT DEFAULT NULL,
  `updated_at` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`passport`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_empregos` (
  `passport` VARCHAR(80) NOT NULL,
  `job` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(120) NOT NULL DEFAULT '',
  `xp` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`passport`, `job`),
  KEY `job_score` (`job`, `xp`),
  KEY `passport_score` (`passport`, `xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_empregos_rewards` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `cycle_key` VARCHAR(40) NOT NULL,
  `ranking_type` VARCHAR(20) NOT NULL,
  `job` VARCHAR(80) NOT NULL DEFAULT '',
  `passport` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(120) NOT NULL DEFAULT '',
  `position` INT NOT NULL,
  `amount` INT NOT NULL,
  `claimed` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` BIGINT NOT NULL,
  `claimed_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ranking_reward` (`cycle_key`, `ranking_type`, `job`, `passport`),
  KEY `pending_reward` (`passport`, `claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_raspadinhas` (
  `passport` VARCHAR(80) NOT NULL,
  `last_play` DATE NOT NULL,
  `chosen_card` INT NOT NULL DEFAULT 1,
  `reward_id` VARCHAR(80) DEFAULT NULL,
  `reward_amount` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`passport`, `last_play`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_factions` (
  `faction_key` VARCHAR(80) NOT NULL,
  `owner_identifier` VARCHAR(80) DEFAULT NULL,
  `owner_name` VARCHAR(120) DEFAULT NULL,
  `group_name` VARCHAR(80) NOT NULL,
  `monthly_price` INT NOT NULL DEFAULT 0,
  `member_limit` INT NOT NULL DEFAULT 20,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `paid_until` BIGINT DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`faction_key`),
  KEY `owner_identifier` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `playtime` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL;
ALTER TABLE `magic_empregos` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL;
ALTER TABLE `magic_raspadinhas` MODIFY COLUMN `passport` VARCHAR(80) NOT NULL;

CREATE TABLE IF NOT EXISTS `magic_pause_tickets` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `passport` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(120) NOT NULL DEFAULT '',
  `category` VARCHAR(40) NOT NULL DEFAULT 'support',
  `title` VARCHAR(120) NOT NULL DEFAULT '',
  `status` VARCHAR(30) NOT NULL DEFAULT 'open',
  `assigned_passport` VARCHAR(80) DEFAULT NULL,
  `assigned_name` VARCHAR(120) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  `closed_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `passport_status` (`passport`, `status`),
  KEY `status_updated` (`status`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_ticket_messages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `ticket_id` INT NOT NULL,
  `passport` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(120) NOT NULL DEFAULT '',
  `staff` TINYINT(1) NOT NULL DEFAULT 0,
  `message` TEXT NOT NULL,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ticket_created` (`ticket_id`, `created_at`),
  CONSTRAINT `fk_magic_pause_ticket_messages`
    FOREIGN KEY (`ticket_id`) REFERENCES `magic_pause_tickets` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_seasons` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(120) NOT NULL DEFAULT 'Passe de Batalha',
  `subtitle` VARCHAR(220) NOT NULL DEFAULT '',
  `starts_at` BIGINT NOT NULL DEFAULT 0,
  `ends_at` BIGINT NOT NULL DEFAULT 0,
  `premium_price` INT NOT NULL DEFAULT 1000,
  `xp_per_level` INT NOT NULL DEFAULT 1000,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `active_updated` (`active`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_slots` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `season_id` INT NOT NULL,
  `slot_index` INT NOT NULL,
  `title` VARCHAR(120) NOT NULL DEFAULT '',
  `subtitle` VARCHAR(180) NOT NULL DEFAULT '',
  `image` VARCHAR(255) NOT NULL DEFAULT '',
  `xp_required` INT NOT NULL DEFAULT 0,
  `free_reward` LONGTEXT DEFAULT NULL,
  `premium_reward` LONGTEXT DEFAULT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `season_slot` (`season_id`, `slot_index`),
  KEY `season_order` (`season_id`, `slot_index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_battlepass_progress` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `passport` VARCHAR(80) NOT NULL,
  `season_id` INT NOT NULL,
  `xp` INT NOT NULL DEFAULT 0,
  `premium` TINYINT(1) NOT NULL DEFAULT 0,
  `claimed_free` LONGTEXT DEFAULT NULL,
  `claimed_premium` LONGTEXT DEFAULT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `passport_season` (`passport`, `season_id`),
  KEY `season_xp` (`season_id`, `xp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_vip_orders` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `passport` VARCHAR(80) NOT NULL,
  `player_name` VARCHAR(120) NOT NULL,
  `product_id` VARCHAR(80) NOT NULL,
  `product_title` VARCHAR(120) NOT NULL,
  `payment_method` VARCHAR(20) NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
  `external_id` VARCHAR(120) DEFAULT NULL,
  `amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `currency` VARCHAR(16) NOT NULL DEFAULT 'runes',
  `metadata` LONGTEXT DEFAULT NULL,
  `delivered` TINYINT(1) NOT NULL DEFAULT 0,
    `delivery_token` VARCHAR(96) DEFAULT NULL,
    `delivery_started_at` BIGINT DEFAULT NULL,
    `delivery_error` VARCHAR(255) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `paid_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `passport_created` (`passport`, `created_at`),
  KEY `status_created` (`status`, `created_at`),
  KEY `passport_payment_status` (`passport`, `payment_method`, `status`, `created_at`),
  KEY `external_id` (`external_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_vip_coupons` (
  `code` VARCHAR(40) NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `percent` DECIMAL(6,2) DEFAULT NULL,
  `amount` DECIMAL(10,2) DEFAULT NULL,
  `min_runes` INT NOT NULL DEFAULT 0,
  `max_discount` DECIMAL(10,2) DEFAULT NULL,
  `description` VARCHAR(180) NOT NULL DEFAULT '',
  `created_by` VARCHAR(80) DEFAULT NULL,
  `created_at` BIGINT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `magic_pause_account_benefits` (
  `order_id` BIGINT NOT NULL,
  `identifier` VARCHAR(100) NOT NULL,
  `benefit` VARCHAR(64) NOT NULL,
  `amount` INT NOT NULL DEFAULT 1,
  `created_at` BIGINT NOT NULL,
  PRIMARY KEY (`order_id`, `benefit`),
  KEY `identifier_benefit` (`identifier`, `benefit`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
