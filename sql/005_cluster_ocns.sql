USE `ht_repository`;

DROP TABLE IF EXISTS `cluster_ocns`;
CREATE TABLE `cluster_ocns` (
  cluster_id int NOT NULL,
  ocn int NOT NULL,
  PRIMARY KEY (ocn),
  INDEX (cluster_id)
) ENGINE=InnoDB;
