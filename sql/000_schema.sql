--
-- Table structure for table `ht_billing_members`
--

DROP TABLE IF EXISTS `ht_billing_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ht_billing_members` (
  `inst_id` varchar(32) DEFAULT NULL,
  `parent_inst_id` varchar(32) DEFAULT NULL,
  `weight` decimal(4,2) DEFAULT NULL,
  `oclc_sym` varchar(10) DEFAULT NULL,
  `marc21_sym` varchar(10) DEFAULT NULL,
  `country_code` char(2) NOT NULL DEFAULT 'us',
  `status` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `ht_collections`
--

DROP TABLE IF EXISTS `ht_collections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ht_collections` (
  `collection` varchar(16) NOT NULL,
  `content_provider_cluster` varchar(255) DEFAULT NULL,
  `responsible_entity` varchar(64) DEFAULT NULL,
  `original_from_inst_id` varchar(32) DEFAULT NULL,
  `billing_entity` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`collection`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `ht_institutions`;
CREATE TABLE `ht_institutions` (
  `inst_id` varchar(64) PRIMARY KEY NOT NULL,
  `grin_instance` varchar(8) DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `template` varchar(256) DEFAULT NULL,
  `domain` varchar(32) DEFAULT NULL,
  `us` tinyint(1) NOT NULL DEFAULT 0,
  `mapto_inst_id` varchar(32) NOT NULL,
  `mapto_name` varchar(256) DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 0,
  `entityID` varchar(256) DEFAULT NULL,
  `allowed_affiliations` text DEFAULT NULL,
  `shib_authncontext_class` varchar(255) DEFAULT NULL,
  `emergency_status` text DEFAULT NULL,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  KEY `ht_institutions_inst_id` (`inst_id`),
  KEY `ht_institutions_mapto_inst_id` (`mapto_inst_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

DROP TABLE IF EXISTS `holdings_htitem_htmember`;
CREATE TABLE `holdings_htitem_htmember` (
  `lock_id` varchar(300) NOT NULL,
  `cluster_id` varchar(25) NOT NULL,
  `volume_id` varchar(50) NOT NULL,
  `n_enum` varchar(250) DEFAULT '',
  `member_id` varchar(20) NOT NULL,
  `copy_count` int(11) DEFAULT NULL,
  `lm_count` smallint(6) DEFAULT NULL,
  `wd_count` smallint(6) DEFAULT NULL,
  `brt_count` smallint(6) DEFAULT NULL,
  `access_count` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`volume_id`, `member_id`),
  KEY (`member_id`),
  KEY (`cluster_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `holdings_loaded_files`;
CREATE TABLE `holdings_loaded_files` (
  `filename` varchar(255) NOT NULL,
  `produced` date NOT NULL,
  `loaded` datetime NOT NULL,
  `source` varchar(64) NOT NULL,
  `type` varchar(32) NOT NULL,
  PRIMARY KEY (`filename`),
  KEY (`type`,`source`,`produced`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `holdings`;
CREATE TABLE `holdings` (
  `ocn`          int(11) NOT NULL,
  `organization` varchar(64) NOT NULL,
  `local_id`     varchar(255) NOT NULL,
  `enum_chron`   varchar(255) NULL,
  `n_enum`       varchar(255) NULL,
  `n_chron`      varchar(255) NULL,
  `n_enum_chron` varchar(255) NULL,
  `status`       enum('CH', 'LM', 'WD') NULL,
  `condition`    enum('BRT', '') NULL,
  `gov_doc_flag` tinyint(1),
  `mono_multi_serial` enum('mix', 'mon', 'spm', 'mpm', 'ser') NOT NULL,
  `date_received` date NOT NULL,
  `uuid`         char(36) PRIMARY KEY NOT NULL,
  `issn`         varchar(255) NULL,
  `delete_flag`  tinyint(1) DEFAULT 0,
  KEY (`ocn`),
  KEY (`organization`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS `oclc_concordance`;
CREATE TABLE `oclc_concordance` (
  `variant` bigint unsigned NOT NULL,
  `canonical` bigint unsigned DEFAULT NULL,
  PRIMARY KEY (`variant`,`canonical`),
  INDEX (`canonical`)
) ENGINE=InnoDB
