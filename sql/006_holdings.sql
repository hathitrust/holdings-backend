use `ht_repository`;

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
  `gov_doc_flag` tinyint(1) DEFAULT '0' NOT NULL,
  `mono_multi_serial` enum('mix', 'mon', 'spm', 'mpm', 'ser') NOT NULL,
  `date_received` datetime NOT NULL,
  `uuid`         char(36) NOT NULL,
  `issn`         varchar(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
