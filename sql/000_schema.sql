-- MySQL dump 10.16  Distrib 10.1.45-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: mysql-sdr    Database: ht_repository
-- ------------------------------------------------------
-- Server version	10.1.44-MariaDB-0+deb9u1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `ht_billing_members`
--

CREATE DATABASE IF NOT EXISTS `ht_repository`;

USE `ht_repository`;

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
  `status` smallint(6) DEFAULT NULL
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
/*!40101 SET character_set_client = @saved_cs_client */;
