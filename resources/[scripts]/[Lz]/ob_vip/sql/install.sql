CREATE TABLE IF NOT EXISTS `ob_vip_memberships` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) NOT NULL,
  `vip` varchar(50) NOT NULL,
  `starts_at` bigint unsigned NOT NULL,
  `expires_at` bigint unsigned DEFAULT NULL,
  `next_salary_at` bigint unsigned DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `granted_by` varchar(64) DEFAULT NULL,
  `grant_reason` varchar(120) DEFAULT NULL,
  `metadata` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_vip_citizen_active` (`citizenid`, `active`, `expires_at`),
  KEY `idx_ob_vip_salary_due` (`active`, `next_salary_at`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_vip_salary_history` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `membership_id` bigint unsigned NOT NULL,
  `citizenid` varchar(64) NOT NULL,
  `vip` varchar(50) NOT NULL,
  `amount` bigint unsigned NOT NULL,
  `account` varchar(20) NOT NULL,
  `scheduled_at` bigint unsigned NOT NULL,
  `paid_at` bigint unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL,
  `error` varchar(160) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_vip_salary_citizen` (`citizenid`, `created_at`),
  KEY `idx_ob_vip_salary_membership` (`membership_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_vip_entitlements` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `membership_id` bigint unsigned NOT NULL,
  `citizenid` varchar(64) NOT NULL,
  `vip` varchar(50) NOT NULL,
  `benefit_kind` varchar(24) NOT NULL,
  `slot_index` int unsigned NOT NULL DEFAULT 1,
  `item_name` varchar(80) DEFAULT NULL,
  `amount` bigint unsigned NOT NULL DEFAULT 1,
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `claim_token` varchar(100) DEFAULT NULL,
  `selection` varchar(80) DEFAULT NULL,
  `metadata` longtext DEFAULT NULL,
  `error` varchar(160) DEFAULT NULL,
  `claimed_at` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_vip_entitlement` (`membership_id`,`benefit_kind`,`slot_index`),
  KEY `idx_ob_vip_entitlement_pending` (`citizenid`,`status`,`benefit_kind`),
  KEY `idx_ob_vip_entitlement_membership` (`membership_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_vip_backpacks` (
  `citizenid` varchar(64) NOT NULL,
  `item_name` varchar(80) NOT NULL,
  `equipped` tinyint(1) NOT NULL DEFAULT 1,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_vip_vehicle_rentals` (
  `vehicle_id` int unsigned NOT NULL,
  `citizenid` varchar(64) NOT NULL,
  `membership_id` bigint unsigned DEFAULT NULL,
  `entitlement_id` bigint unsigned DEFAULT NULL,
  `vip` varchar(50) NOT NULL,
  `model` varchar(80) NOT NULL,
  `starts_at` bigint unsigned NOT NULL,
  `expires_at` bigint unsigned NOT NULL,
  `duration_days` smallint unsigned NOT NULL DEFAULT 30,
  `renewal_runes` bigint unsigned NOT NULL DEFAULT 0,
  `renewal_count` int unsigned NOT NULL DEFAULT 0,
  `last_renewed_at` bigint unsigned DEFAULT NULL,
  `source_kind` varchar(24) NOT NULL DEFAULT 'vip',
  `source_id` varchar(120) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`vehicle_id`),
  UNIQUE KEY `uq_ob_vip_vehicle_entitlement` (`entitlement_id`),
  UNIQUE KEY `uq_ob_vip_vehicle_source` (`citizenid`, `source_kind`, `source_id`),
  KEY `idx_ob_vip_vehicle_citizen` (`citizenid`, `expires_at`),
  KEY `idx_ob_vip_vehicle_membership` (`membership_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_vip_rental_payments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(64) NOT NULL,
  `rental_kind` varchar(20) NOT NULL,
  `reference_id` varchar(64) NOT NULL,
  `vip` varchar(50) NOT NULL,
  `runes` bigint unsigned NOT NULL,
  `previous_expires_at` bigint unsigned DEFAULT NULL,
  `expires_at` bigint unsigned NOT NULL,
  `paid_at` bigint unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_vip_rental_citizen` (`citizenid`, `created_at`),
  KEY `idx_ob_vip_rental_reference` (`rental_kind`, `reference_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
