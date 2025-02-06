USE `ht_repository`;

DROP TABLE IF EXISTS `cluster_ocns`;
CREATE TABLE `cluster_ocns` (
  cluster_id int unsigned NOT NULL,
  ocn bigint unsigned NOT NULL,
  PRIMARY KEY (ocn),
  INDEX (cluster_id)
) ENGINE=InnoDB;

CREATE SEQUENCE IF NOT EXISTS `cluster_ids`;
