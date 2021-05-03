USE `ht_repository`;

CREATE TABLE IF NOT EXISTS `holdings_htitem_htmember` (
  `lock_id` varchar(100) NOT NULL,
  `cluster_id` bigint NOT NULL,
  `volume_id` varchar(50) NOT NULL,
  `n_enum` varchar(50) DEFAULT '',
  `member_id` varchar(20) NOT NULL,
  `copy_count` int(11) DEFAULT NULL,
  `lm_count` smallint(6) DEFAULT NULL,
  `wd_count` smallint(6) DEFAULT NULL,
  `brt_count` smallint(6) DEFAULT NULL,
  `access_count` smallint(6) DEFAULT NULL,
  PRIMARY KEY (`volume_id`, `member_id`),
  KEY (`member_id`),
  KEY (`cluster_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
