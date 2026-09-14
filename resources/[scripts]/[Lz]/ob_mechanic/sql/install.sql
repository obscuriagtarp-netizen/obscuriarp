-- ob_mechanic
-- Banco: MariaDB/MySQL com oxmysql
-- Este instalador e idempotente e nao remove dados existentes.

CREATE TABLE IF NOT EXISTS `ob_mechanic_pending` (
    `citizenid` varchar(64) NOT NULL,
    `plate` varchar(16) NOT NULL,
    `payload` longtext NOT NULL,
    `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (`citizenid`, `plate`),
    KEY `idx_ob_mechanic_pending_updated` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
