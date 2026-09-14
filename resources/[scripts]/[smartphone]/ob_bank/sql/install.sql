CREATE TABLE IF NOT EXISTS `ob_bank_pix` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `transfer_id` VARCHAR(64) NOT NULL,
  `request_id` VARCHAR(64) NOT NULL,
  `sender_citizenid` VARCHAR(64) NOT NULL,
  `sender_name` VARCHAR(120) NOT NULL,
  `recipient_citizenid` VARCHAR(64) NOT NULL,
  `recipient_name` VARCHAR(120) NOT NULL,
  `amount` BIGINT UNSIGNED NOT NULL,
  `description` VARCHAR(80) NOT NULL DEFAULT '',
  `status` VARCHAR(24) NOT NULL DEFAULT 'processing',
  `failure_reason` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_bank_pix_transfer` (`transfer_id`),
  UNIQUE KEY `uq_ob_bank_pix_request` (`sender_citizenid`, `request_id`),
  KEY `idx_ob_bank_pix_sender` (`sender_citizenid`, `created_at`),
  KEY `idx_ob_bank_pix_recipient` (`recipient_citizenid`, `created_at`),
  KEY `idx_ob_bank_pix_status` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_bank_pix_favorites` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner_citizenid` VARCHAR(64) NOT NULL,
  `recipient_citizenid` VARCHAR(64) NOT NULL,
  `recipient_name` VARCHAR(120) NOT NULL,
  `nickname` VARCHAR(40) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_bank_favorite` (`owner_citizenid`, `recipient_citizenid`),
  KEY `idx_ob_bank_favorite_owner` (`owner_citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_bank_credit_accounts` (
  `citizenid` VARCHAR(64) NOT NULL,
  `score` SMALLINT UNSIGNED NOT NULL DEFAULT 350,
  `credit_limit` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL DEFAULT 'active',
  `blocked_reason` VARCHAR(32) DEFAULT NULL,
  `blocked_at` TIMESTAMP NULL DEFAULT NULL,
  `last_scored_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_ob_credit_account_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_bank_credit_invoices` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(64) NOT NULL,
  `cycle_start` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `due_at` TIMESTAMP NOT NULL,
  `principal` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `interest` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `paid_amount` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL DEFAULT 'open',
  `interest_last_applied` DATE DEFAULT NULL,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ob_credit_invoice_owner` (`citizenid`, `status`, `due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_bank_credit_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `transaction_id` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `invoice_id` BIGINT UNSIGNED DEFAULT NULL,
  `transaction_type` VARCHAR(16) NOT NULL,
  `amount` BIGINT UNSIGNED NOT NULL,
  `merchant` VARCHAR(100) NOT NULL DEFAULT 'Obscuria',
  `description` VARCHAR(180) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_credit_transaction` (`transaction_id`),
  KEY `idx_ob_credit_transaction_owner` (`citizenid`, `created_at`),
  KEY `idx_ob_credit_transaction_invoice` (`invoice_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
