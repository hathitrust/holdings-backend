USE `ht_repository`;

CREATE TABLE IF NOT EXISTS `holdings_loaded_files` (
  `filename` varchar(255) NOT NULL,
  `produced` date NOT NULL,
  `loaded` datetime NOT NULL,
  `source` varchar(64) NOT NULL,
  `type` varchar(32) NOT NULL,
  PRIMARY KEY (`filename`),
  KEY (`type`,`source`,`produced`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
