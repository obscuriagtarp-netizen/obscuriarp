CREATE TABLE IF NOT EXISTS `ob_hospital_patients` (
  `citizenid` varchar(64) NOT NULL,
  `name` varchar(96) NOT NULL,
  `blood_type` varchar(8) NOT NULL DEFAULT '',
  `allergies` varchar(500) NOT NULL DEFAULT '',
  `conditions` varchar(1000) NOT NULL DEFAULT '',
  `notes` text NULL,
  `photo_url` varchar(600) NOT NULL DEFAULT '',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`citizenid`),
  KEY `idx_ob_hospital_patient_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_records` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_identifier` varchar(64) NOT NULL,
  `patient_name` varchar(96) NOT NULL,
  `medic_identifier` varchar(64) NOT NULL,
  `medic_name` varchar(96) NOT NULL,
  `record_type` varchar(24) NOT NULL DEFAULT 'consultation',
  `title` varchar(120) NOT NULL,
  `notes` text NULL,
  `diagnosis` text NULL,
  `treatment` text NULL,
  `severity` varchar(24) NOT NULL DEFAULT 'stable',
  `body_parts` longtext NOT NULL,
  `vitals` longtext NOT NULL,
  `photos` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_hospital_records_patient` (`patient_identifier`,`created_at`),
  KEY `idx_ob_hospital_records_medic` (`medic_identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_photos` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `record_id` bigint unsigned NOT NULL,
  `patient_identifier` varchar(64) NOT NULL,
  `url` varchar(600) NOT NULL,
  `caption` varchar(180) NOT NULL DEFAULT '',
  `created_by` varchar(64) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_hospital_photos_patient` (`patient_identifier`,`created_at`),
  CONSTRAINT `fk_ob_hospital_photo_record` FOREIGN KEY (`record_id`) REFERENCES `ob_hospital_records` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_calls` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `public_code` varchar(16) NOT NULL,
  `patient_identifier` varchar(64) NULL,
  `patient_name` varchar(96) NOT NULL,
  `patient_source` int NULL,
  `reason` varchar(500) NOT NULL,
  `priority` varchar(24) NOT NULL DEFAULT 'normal',
  `status` varchar(24) NOT NULL DEFAULT 'waiting',
  `coords` longtext NOT NULL,
  `assigned_identifier` varchar(64) NULL,
  `assigned_name` varchar(96) NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `resolved_at` datetime NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_hospital_call_code` (`public_code`),
  KEY `idx_ob_hospital_calls_board` (`status`,`priority`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_queue` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ticket_code` varchar(24) NULL,
  `patient_identifier` varchar(64) NOT NULL,
  `patient_name` varchar(96) NOT NULL,
  `patient_source` int NULL,
  `status` varchar(24) NOT NULL DEFAULT 'waiting',
  `called_by_identifier` varchar(64) NULL,
  `called_by_name` varchar(96) NULL,
  `called_by_title` varchar(16) NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `called_at` datetime NULL,
  `started_at` datetime NULL,
  `resolved_at` datetime NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_hospital_queue_code` (`ticket_code`),
  KEY `idx_ob_hospital_queue_status` (`status`,`called_at`,`created_at`),
  KEY `idx_ob_hospital_queue_patient` (`patient_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_activity` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `actor_identifier` varchar(64) NOT NULL,
  `actor_name` varchar(96) NOT NULL,
  `action` varchar(48) NOT NULL,
  `payload` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_hospital_activity_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_invoices` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `public_code` varchar(24) NOT NULL,
  `patient_identifier` varchar(64) NOT NULL,
  `patient_name` varchar(96) NOT NULL,
  `patient_source` int NULL,
  `employee_identifier` varchar(64) NOT NULL,
  `employee_name` varchar(96) NOT NULL,
  `description` varchar(500) NOT NULL,
  `amount` int unsigned NOT NULL,
  `status` varchar(24) NOT NULL DEFAULT 'pending',
  `expires_at` datetime NULL,
  `paid_at` datetime NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_hospital_invoice_code` (`public_code`),
  KEY `idx_ob_hospital_invoice_patient` (`patient_identifier`,`status`,`created_at`),
  KEY `idx_ob_hospital_invoice_status` (`status`,`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_subscriptions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_identifier` varchar(64) NOT NULL,
  `patient_name` varchar(96) NOT NULL,
  `patient_source` int NULL,
  `status` varchar(24) NOT NULL DEFAULT 'pending',
  `monthly_price` int unsigned NOT NULL,
  `created_by_identifier` varchar(64) NOT NULL,
  `created_by_name` varchar(96) NOT NULL,
  `starts_at` datetime NULL,
  `next_charge_at` datetime NULL,
  `last_charge_at` datetime NULL,
  `cancelled_at` datetime NULL,
  `failure_count` int unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_hospital_subscription_patient` (`patient_identifier`),
  KEY `idx_ob_hospital_subscription_due` (`status`,`next_charge_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_hospital_billing_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `patient_identifier` varchar(64) NOT NULL,
  `invoice_id` bigint unsigned NULL,
  `subscription_id` bigint unsigned NULL,
  `transaction_type` varchar(24) NOT NULL,
  `amount` int unsigned NOT NULL,
  `status` varchar(24) NOT NULL,
  `description` varchar(500) NOT NULL DEFAULT '',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_hospital_transaction_patient` (`patient_identifier`,`created_at`),
  KEY `idx_ob_hospital_transaction_invoice` (`invoice_id`),
  KEY `idx_ob_hospital_transaction_subscription` (`subscription_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
