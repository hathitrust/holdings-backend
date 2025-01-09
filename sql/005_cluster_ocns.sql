USE `ht_repository`;

CREATE TABLE IF NOT EXISTS `cluster_ocns` (
  cluster_id int NOT NULL,
  ocn int NOT NULL,
  PRIMARY KEY (ocn),
  INDEX (cluster_id)
) ENGINE=InnoDB;
