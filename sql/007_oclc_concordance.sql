use `ht_repository`;

DROP TABLE IF EXISTS `oclc_concordance`;
CREATE TABLE `oclc_concordance` (
  `oclc` int(10) unsigned NOT NULL,
  `canonical` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`oclc`,`canonical`),
  INDEX (`canonical`)
) ENGINE=InnoDB
