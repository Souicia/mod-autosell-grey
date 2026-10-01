CREATE TABLE IF NOT EXISTS `character_autosell_settings` (
  `guid` int unsigned NOT NULL,
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  `chat_enabled` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB;
