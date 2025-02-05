use `ht_repository`;

DROP TABLE IF EXISTS `oclc_concordance`;
CREATE TABLE `oclc_concordance` (
  `oclc` bigint unsigned NOT NULL,
  `canonical` bigint unsigned DEFAULT NULL,
  PRIMARY KEY (`oclc`,`canonical`),
  INDEX (`canonical`)
) ENGINE=InnoDB
