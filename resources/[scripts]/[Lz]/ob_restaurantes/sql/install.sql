CREATE TABLE IF NOT EXISTS `ob_restaurants` (
  `id` varchar(64) NOT NULL,
  `label` varchar(96) NOT NULL,
  `job` varchar(64) NOT NULL,
  `manager_grade` int NOT NULL DEFAULT 4,
  `commission_rate` decimal(5,4) NOT NULL DEFAULT 0.3000,
  `theme` varchar(32) NOT NULL DEFAULT 'obscuria',
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `is_open` tinyint(1) NOT NULL DEFAULT 1,
  `description` varchar(255) NOT NULL DEFAULT '',
  `cover_url` varchar(255) NOT NULL DEFAULT '',
  `menu_image_url` varchar(255) NOT NULL DEFAULT '',
  `notes` text NULL,
  `notes_updated_by` varchar(96) NULL,
  `notes_updated_at` datetime NULL,
  `feature_menu` tinyint(1) NOT NULL DEFAULT 1,
  `feature_location` tinyint(1) NOT NULL DEFAULT 1,
  `feature_call` tinyint(1) NOT NULL DEFAULT 1,
  `location_label` varchar(160) NOT NULL DEFAULT '',
  `call_text` varchar(255) NOT NULL DEFAULT '',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_restaurants_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_points` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `type` varchar(24) NOT NULL,
  `label` varchar(96) NOT NULL,
  `coords` longtext NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_ob_points_restaurant` (`restaurant_id`),
  CONSTRAINT `fk_ob_points_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `category_key` varchar(48) NOT NULL,
  `label` varchar(80) NOT NULL,
  `icon` varchar(48) NOT NULL DEFAULT 'utensils',
  `sort_order` int NOT NULL DEFAULT 0,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_category` (`restaurant_id`,`category_key`),
  CONSTRAINT `fk_ob_categories_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_recipes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `recipe_key` varchar(64) NOT NULL,
  `category_key` varchar(48) NOT NULL,
  `name` varchar(96) NOT NULL,
  `description` varchar(255) NOT NULL DEFAULT '',
  `image` varchar(255) NOT NULL DEFAULT '',
  `icon` varchar(48) NOT NULL DEFAULT 'utensils',
  `price` int unsigned NOT NULL DEFAULT 0,
  `old_price` int unsigned NULL,
  `menu_badge` varchar(32) NOT NULL DEFAULT '',
  `featured` tinyint(1) NOT NULL DEFAULT 0,
  `prep_time` int unsigned NOT NULL DEFAULT 5,
  `output_item` varchar(64) NOT NULL,
  `output_amount` int unsigned NOT NULL DEFAULT 1,
  `is_combo` tinyint(1) NOT NULL DEFAULT 0,
  `ingredients` longtext NOT NULL,
  `contents` longtext NULL,
  `craft_steps` longtext NULL,
  `effects` longtext NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_recipe` (`restaurant_id`,`recipe_key`),
  KEY `idx_ob_recipe_category` (`restaurant_id`,`category_key`),
  CONSTRAINT `fk_ob_recipes_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_orders` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `public_code` varchar(16) NOT NULL,
  `restaurant_id` varchar(64) NOT NULL,
  `customer_identifier` varchar(80) NULL,
  `customer_source` int NULL,
  `customer_name` varchar(96) NOT NULL,
  `employee_identifier` varchar(80) NOT NULL,
  `employee_source` int NULL,
  `employee_name` varchar(96) NOT NULL,
  `items` longtext NOT NULL,
  `notes` varchar(500) NOT NULL DEFAULT '',
  `subtotal` int unsigned NOT NULL,
  `total` int unsigned NOT NULL,
  `status` varchar(24) NOT NULL DEFAULT 'awaiting_payment',
  `payment_id` bigint unsigned NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_order_code` (`restaurant_id`,`public_code`),
  KEY `idx_ob_orders_restaurant_status` (`restaurant_id`,`status`,`created_at`),
  CONSTRAINT `fk_ob_orders_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_payments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `order_id` bigint unsigned NULL,
  `employee_identifier` varchar(80) NOT NULL,
  `employee_source` int NULL,
  `employee_name` varchar(96) NOT NULL,
  `customer_identifier` varchar(80) NULL,
  `customer_source` int NULL,
  `amount` int unsigned NOT NULL,
  `account` varchar(16) NULL,
  `status` varchar(24) NOT NULL DEFAULT 'pending',
  `expires_at` datetime NOT NULL,
  `paid_at` datetime NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_payments_customer` (`restaurant_id`,`customer_source`,`status`),
  KEY `idx_ob_payments_order` (`order_id`),
  CONSTRAINT `fk_ob_payments_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_sales` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `order_id` bigint unsigned NULL,
  `payment_id` bigint unsigned NOT NULL,
  `employee_identifier` varchar(80) NOT NULL,
  `employee_name` varchar(96) NOT NULL,
  `gross` int unsigned NOT NULL,
  `commission` int unsigned NOT NULL,
  `company_net` int unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_sale_payment` (`payment_id`),
  KEY `idx_ob_sales_dashboard` (`restaurant_id`,`created_at`),
  CONSTRAINT `fk_ob_sales_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_accounts` (
  `restaurant_id` varchar(64) NOT NULL,
  `balance` bigint NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`restaurant_id`),
  CONSTRAINT `fk_ob_accounts_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_commissions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `sale_id` bigint unsigned NOT NULL,
  `employee_identifier` varchar(80) NOT NULL,
  `amount` int unsigned NOT NULL,
  `status` varchar(16) NOT NULL DEFAULT 'pending',
  `paid_at` datetime NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ob_commission_sale` (`sale_id`),
  KEY `idx_ob_commission_employee` (`employee_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_productions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `recipe_id` int unsigned NOT NULL,
  `employee_identifier` varchar(80) NOT NULL,
  `employee_source` int NULL,
  `status` varchar(16) NOT NULL DEFAULT 'preparing',
  `ready_at` datetime NOT NULL,
  `collected_at` datetime NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_production_employee` (`employee_identifier`,`status`),
  CONSTRAINT `fk_ob_productions_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ob_productions_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `ob_restaurant_recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_announcements` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `order_id` bigint unsigned NOT NULL,
  `message` varchar(255) NOT NULL,
  `start_at` bigint unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_announcements_restaurant` (`restaurant_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ob_restaurant_audit` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `restaurant_id` varchar(64) NOT NULL,
  `actor_identifier` varchar(80) NOT NULL,
  `actor_name` varchar(96) NOT NULL,
  `action` varchar(48) NOT NULL,
  `details` longtext NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ob_audit_restaurant` (`restaurant_id`,`created_at`),
  KEY `idx_ob_audit_actor` (`actor_identifier`,`created_at`),
  CONSTRAINT `fk_ob_audit_restaurant` FOREIGN KEY (`restaurant_id`) REFERENCES `ob_restaurants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
