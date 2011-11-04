CREATE DATABASE /*!32312 IF NOT EXISTS*/ `AMMS` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

USE `AMMS`;

--
-- Table structure for table `market`
--

DROP TABLE IF EXISTS `market`;
CREATE TABLE `market` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) collate utf8_bin NOT NULL,
  `language` varchar(32) collate utf8_bin NOT NULL,
  `feeder_entity_of_task` int(11) NOT NULL,
  `interval_of_discovery` int(11) NOT NULL default '3',
  `interval_of_update` int(11) NOT NULL default '12',
  `status` enum('active','inactive') collate utf8_bin default 'active',
  `start_crawl_time` datetime default NULL,
  `access_url` varchar(255) collate utf8_bin NOT NULL,
  `developer_url` varchar(255) collate utf8_bin NOT NULL,
  `cover_country` varchar(32) collate utf8_bin NOT NULL,
  `supported_language` varchar(32) collate utf8_bin NOT NULL,
  `header_quarter` varchar(32) collate utf8_bin NOT NULL,
  `setup_date` datetime default NULL,
  `description` varchar(255) collate utf8_bin NOT NULL,
  `display_name` varchar(255) collate utf8_bin NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;


--
-- Table structure for table `feeder`
--

DROP TABLE IF EXISTS `feeder`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `feeder` (
  `feeder_id` int(11) NOT NULL auto_increment,
  `feeder_url` varchar(255) collate utf8_bin NOT NULL,
  `market_id` int(11) NOT NULL,
  `parent_category` varchar(100) collate utf8_bin default NULL,
  `sub_category` varchar(100) collate utf8_bin default NULL,
  `last_visited_time` datetime default NULL,
  `status` enum('undo','doing','success','fail','invalid') collate utf8_bin default 'undo',
  PRIMARY KEY  (`feeder_id`),
  KEY `market_idx` (`market_id`),
  UNIQUE `feeder.feeder_url` (feeder_url) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `feed_info`
--

DROP TABLE IF EXISTS `feed_info`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `feed_info` (
  `feed_url_md5` varchar(32) collate utf8_bin NOT NULL,
  `feed_url` varchar(255) collate utf8_bin NOT NULL,
  `feeder_id` int(11) NOT NULL,
  `last_visited_time` datetime default NULL,
  `status` enum('undo','doing','success','fail','invalid') collate utf8_bin default 'undo',
  PRIMARY KEY  (`feed_url_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `app_source`
--

DROP TABLE IF EXISTS `app_source`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `app_source` (
  `app_url_md5` char(32) NOT NULL,
  `app_url` varchar(255) NOT NULL,
  `app_self_id` varchar(255) NOT NULL,
  `market_id` int(11) NOT NULL,
  `feeder_id` int(11) NOT NULL,
  `status` enum('undo','doing','fail','success','invalid') default 'undo',
  `last_visited_time` datetime default NULL,
  PRIMARY KEY  (`app_url_md5`),
  KEY `app_source.app_url` (`app_url`),
  KEY `app_source.market_id` (`market_id`),
  KEY `app_source.feeder_id` (`feeder_id`),
  KEY `app_source.app_self_id` (`app_self_id`),
  KEY `app_source.status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `app_info`
--

DROP TABLE IF EXISTS `app_info`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `app_info` (
  `app_url_md5` char(32) NOT NULL,
  `app_name` varchar(100) NOT NULL,
  `official_category` varchar(100) NOT NULL,
  `official_sub_category` varchar(100) NOT NULL,
  `trustgo_category_id` varchar(32) NOT NULL,
  `author` varchar(100) default NULL,
  `support_os` varchar(100) NOT NULL,
  `app_capacity` varchar(100) NOT NULL,
  `system_requirement` varchar(64) NOT NULL,
  `max_os_version` varchar(32) NOT NULL,
  `min_os_version` varchar(32) NOT NULL,
  `resolution` varchar(32) NOT NULL,
  `note` varchar(256) default NULL,
  `official_rating_stars` decimal(3,1) NOT NULL,
  `official_rating_times` int(11) NOT NULL,
  `official_comment_times` int(11) NOT NULL,
  `release_date` datetime default NULL,
  `last_update` datetime default NULL,
  `size` int(11) NOT NULL,
  `price` varchar(128) default NULL,
  `currency` varchar (32) default NULL,
  `current_version` varchar(20) default NULL,
  `total_install_times` int(11) default NULL,
  `app_url` varchar(255) default NULL,
  `app_qr` varchar(255) default NULL,
  `website` varchar(255) default NULL,
  `support_website` varchar(255) default NULL,
  `language` varchar(255) default NULL,
  `copyright` varchar(100) default NULL,
  `age_rating` varchar(32) default NULL,
  `permission` bigint(20) default NULL,
  `last_visited_time` datetime default NULL,
  `first_visited_time` datetime default NULL,
  `last_success_visited_time` datetime default NULL,
  `last_modified_time` datetime default NULL,
  `visited_times` int(11) NOT NULL,
  `updated_times` int(11) NOT NULL,
  `worker_ip` varchar(64) default NULL,
  `market_id` int(11) NOT NULL,
  `delivery_time` datetime default NULL,
  `apk_md5` varchar(32) NOT NULL,
  `status` enum('undo','doing','fail','success','invalid','up_to_date') default 'success',
  PRIMARY KEY  (`app_url_md5`),
  KEY `app_info.app_name` (`app_name`),
  KEY `app_info.apk_md5` (`apk_md5`),
  KEY `app_info.status` (`status`),
  KEY `app_info.worker_ip` (`worker_ip`),
  KEY `app_info.market_id` (`market_id`),
  KEY `app_info.last_visited_time` (`last_visited_time`),
  KEY `app_info.first_visited_time` (`first_visited_time`),
  KEY `app_info.last_modified_time` (`last_modified_time`),
  KEY `app_info.delivery_time` (`delivery_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;


--
-- Table structure for table `app_apk`
--

DROP TABLE IF EXISTS `app_apk`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `app_apk` (
  `app_url_md5` char(32) NOT NULL,
  `apk_md5` varchar(32) NOT NULL,
  `app_unique_name` varchar(255) NOT NULL,
  `apk_url` varchar(255) default NULL,
  `apk_version` varchar(255) default NULL,
  `need_submmit` enum('yes','no') default 'no',
  `insert_time` datetime default NULL,
  `last_visited_time` datetime default NULL,
  `first_visited_time` datetime default NULL,
  `last_success_visited_time` datetime default NULL,
  `last_modified_time` datetime default NULL,
  `visited_times` int(11) NOT NULL,
  `updated_times` int(11) NOT NULL,
  `status` enum('undo','doing','fail','paid','success','invalid') default 'undo',
  PRIMARY KEY  (`app_url_md5`,`apk_md5`),
  KEY `app_apk.status` (`status`),
  KEY `app_apk.last_visited_time` (`last_visited_time`),
  KEY `app_apk.app_unique_name` (`app_unique_name`),
  KEY `app_apk.apk_md5` (`apk_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `log`
--

DROP TABLE IF EXISTS `log`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `log` (
  `pid` int(11) NOT NULL,
  `level` varchar(10) NOT NULL default '',
  `file` varchar(100) NOT NULL default '',
  `line` int(11) NOT NULL,
  `date` datetime NOT NULL default '0000-00-00 00:00:00',
  `mesg` varchar(1024) NOT NULL default '',
  KEY `date_idx` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `task`
--

DROP TABLE IF EXISTS `task`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `task` (
  `task_id` int(11) NOT NULL auto_increment,
  `market_id` int(11) NOT NULL,
  `worker_ip` varchar(64) default NULL,
  `task_type` enum('find_app','new_app','update_app','new_apk','multi_lang','price') NOT NULL,
  `status` enum('undo','doing','done') NOT NULL default 'undo',
  `request_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `done_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `task_changed_time` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`task_id`),
  KEY `ix_task_type` (`task_type`),
  KEY `ix_market_id` (`market_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;


--
-- Table structure for table `task_detail`
--

DROP TABLE IF EXISTS `task_detail`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `task_detail` (
  `task_id` int(11) NOT NULL,
  `detail_id` varchar(32) NOT NULL,
  `detail_info` varchar(256) NOT NULL,
  KEY `ix_task_id` (`task_id`),
  KEY `ix_detail_id` (`detail_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

DROP TABLE IF EXISTS `google_account`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `google_account` (
  `account` varchar(32) ,
  `user_id` varchar(32) NOT NULL,
  `device_id` varchar(32) NOT NULL,
  `auth_sub_token` varchar(256) NOT NULL,
  `last_visited_time` datetime default NULL,
  `last_success_visited_time` datetime default NULL,
  `visited_times` int(11) default 0,
  `fail_times` int(11) default 0,
  PRIMARY KEY (`account`),
  KEY `google_account.last_visited_time` (`last_visited_time`) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

DROP TABLE IF EXISTS `package`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `package` (
  `task_id` int(11) NOT NULL auto_increment,
  `worker_ip` varchar(64) default NULL,
  `package_name` varchar(128) default NULL,
  `status` enum('undo','doing','success','fail') NOT NULL default 'undo',
  `fail_times` int(11) default 0,
  `insert_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime NOT NULL default '0000-00-00 00:00:00',
  KEY `ix_task_id` (`task_id`),
  KEY `ix_worker_ip` (`worker_ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

DROP TABLE IF EXISTS `market_monitor`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `market_monitor` (
  `market_id` int(11) NOT NULL ,
  `cycle` int(11) NOT NULL ,
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `status` enum('doing','done') NOT NULL default 'doing',
  PRIMARY KEY (`market_id`,`cycle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;




DROP TABLE IF EXISTS `app_price`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `app_price` (
  `app_url_md5` char(32) NOT NULL,
  `currency` varchar (32) default NULL,
  `free` TINYINT default 0,
  `status` enum('undo','fail','success') default 'fail',
  `extra_info` varchar(256) default NULL,
  `cs` varchar(32) default NULL,
  `da` varchar(32) default NULL,
  `de` varchar(32) default NULL,
  `en` varchar(32) default NULL,
  `es` varchar(32) default NULL,
  `es_419` varchar(32) default NULL,
  `fr` varchar(32) default NULL,
  `it` varchar(32) default NULL,
  `nl` varchar(32) default NULL,
  `no` varchar(32) default NULL,
  `pt_br` varchar(32) default NULL,
  `pt_pt` varchar(32) default NULL,
  `fi` varchar(32) default NULL,
  `sv` varchar(32) default NULL,
  `tr` varchar(32) default NULL,
  `el` varchar(32) default NULL,
  `ru` varchar(32) default NULL,
  `zh_tw` varchar(32) default NULL,
  `zh_cn` varchar(32) default NULL,
  `ja` varchar(32) default NULL,
  PRIMARY KEY (`app_url_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;


DROP TABLE IF EXISTS `google_multi_lang`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `google_multi_lang` (
  `app_url_md5` char(32) NOT NULL,
  `status` enum('undo','fail','success') default 'fail',
  `cs` TINYINT default 0,
  `da` TINYINT default 0,
  `de` TINYINT default 0,
  `en` TINYINT default 0,
  `es` TINYINT default 0,
  `es_419` TINYINT default 0,
  `fr` TINYINT default 0,
  `it` TINYINT default 0,
  `nl` TINYINT default 0,
  `no` TINYINT default 0,
  `pt_br` TINYINT default 0,
  `pt_pt` TINYINT default 0,
  `fi` TINYINT default 0,
  `sv` TINYINT default 0,
  `tr` TINYINT default 0,
  `el` TINYINT default 0,
  `ru` TINYINT default 0,
  `zh_tw` TINYINT default 0,
  `zh_cn` TINYINT default 0,
  `ja` TINYINT default 0,
  PRIMARY KEY (`app_url_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;


DROP TABLE IF EXISTS `app_extra_info`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `app_extra_info` (
  `app_url_md5` char(32) NOT NULL,
  `last_update` datetime default NULL,
  `category` char(128) default NULL,
  `amazon_interval_version` char(32) default NULL,
  `information` varchar(2048) default NULL,
  PRIMARY KEY (`app_url_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

DROP TABLE IF EXISTS `proxy_pool`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `proxy_pool` (
  `ip` char(64) NOT NULL,
  `port` int NOT NULL DEFAULT 0,
  `country` char(128) default "USA",
  `insert_time` datetime default NULL,
  `end_time` datetime default NULL,
  `status` enum('active','inactive') default 'active',
  PRIMARY KEY (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;






INSERT INTO `google_account` VALUES
('crawler111','17558788718787595785','4500701539983183731','DQAAALQAAACsAQnkrAOS7UJx7WhHfc9QeeE0Cj43HEPJgMTV5F5BxNVdNbavvOCETdycyZEmZOebzDRroVp0IfZtH2TwuMMVmMc-W-oxYDl03sAQ3tKlQIVqz_0zgkE04J8_KNMb0cyswERFI8XTWb8RYbwCHX24fJG-tCnFtj3XO6bl4cloE8rWXX0GwuVlG4jTmo6iBZdraKKoPXIF9dzcjsKQomWUE-y3h2FTzoDGMCZSOghqr0HlZ0XApZwK_4mxepQ3Q5M','0000-00-0000:00:00','0000-00-0000:00:00',0,0);

GRANT SELECT,INSERT,UPDATE, DELETE,ALTER,LOCK TABLES ON AMMS.* TO trustgo@"%" IDENTIFIED BY "123456";
GRANT SELECT,LOCK TABLES ON AMMS.* TO onlyread@"%" IDENTIFIED BY "123456";

INSERT INTO `market` VALUES (1,'market.android.com','en_us',2,3,12,'good',NULL,'http://www.android.com/market/','http://developer.android.com/','67 countries','multiple\r\n       languages','CA,US',NULL,'','Android Market'),(2,'www.mumayi.com','zh_cn',3,3,12,'good',NULL,'http://www.mumayi.com/','','','','jiangsu, CN',NULL,'','木蚂蚁应用市场'),(3,'www.amazon.com','en_us',2,3,12,'good',NULL,'','','','','',NULL,'',''),(4,'www.aimi8.com','zh_cn',3,3,12,'good',NULL,'http://www.aimi8.com/','','','','Beijing,CN',NULL,'','爱米软件商店'),(5,'www.hiapk.com','zh_cn',3,3,12,'good',NULL,'www.hiapk.com','','','','Fujian, CN',NULL,'','安卓市场'),(6,'www.gfan.com','zh_cn',3,3,12,'good',NULL,'www.gfan.com','','','','Beijing,CN',NULL,'','机锋市场'),(7,'www.appchina.com','zh_cn',2,3,12,'good',NULL,'www.appchina.com','','','','Beijing,CN',NULL,'','应用汇市场'),(8,'www.nduoa.com','zh_cn',2,3,12,'good',NULL,'www.nduoa.com','','','','Shanghai, CN',NULL,'','N多市场'),(9,'www.eoemarket.com','zh_cn',2,3,12,'good',NULL,'www.eoemarket.com','','','','Beijing,CN',NULL,'','优亿市场'),(10,'www.goapk.com','zh_cn',2,3,12,'good',NULL,'www.goapk.com','','','','CN',NULL,'','安智市场'),(11,'android.d.cn','zh_cn',2,3,12,'good',NULL,'android.d.cn','','','','CN',NULL,'','安致市场'),(12,'m.163.com','zh_cn',2,3,12,'good',NULL,'m.163.com','','','','CN',NULL,'all mobile OS','网易应用'),(13,'appslib.com','',0,3,12,'good',NULL,'http://appslib.com/applications/index.html','http://appslib.com/developers/index.html','128 countries','English','HongKong, HK',NULL,'','AppsLib'),(14,'www.getjar.com','',0,3,12,'good',NULL,'http://www.getjar.com/','http://my.getjar.com/','128 countries','multiple languages','CA, US',NULL,'all mobile OS','GetJar'),(15,'www.189store.com','',0,3,12,'good',NULL,'http://www.189store.com','','','','CN',NULL,'','天翼空间应用商城'),(16,'soft.kaiqi.com','',0,3,12,'good',NULL,'http://soft.kaiqi.com/','','','','CN',NULL,'','开奇网'),(17,'store.wo.com.cn','',0,3,12,'good',NULL,'http://store.wo.com.cn/','','','','CN',NULL,'','沃商店'),(18,'www.starandroid.com','',0,3,12,'good',NULL,'http://www.starandroid.com/','','','','CN',NULL,'','安卓星空'),(19,'www.anfone.com','',0,3,12,'good',NULL,'http://www.anfone.com/index.html','','','','CN',NULL,'','安丰下载'),(20,'www.liqucn.com','',0,3,12,'good',NULL,'http://www.liqucn.com/phone/htc/g8-wildfire/','','','','CN',NULL,'','历趣安卓市场'),(21,'mm.10086.cn','',0,3,12,'good',NULL,'http://mm.10086.cn','','','','CN',NULL,'','移动应用商场');
