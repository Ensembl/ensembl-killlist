# Tables for ensembl_kill db
#
#


################################################################################
#
# Table structure for table 'kill_object'
#

CREATE TABLE kill_object (

  kill_object_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
  taxon_id                    int(10) unsigned, 
  mol_type                    ENUM('protein', 'cDNA', 'EST') NOT NULL,
  accession                   varchar(20),
  version                     varchar(20),
  external_db_id              int(11), 
  description                 TEXT,
  created                     datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  user_id                     INT(10) UNSIGNED NOT NULL, 

  PRIMARY KEY (kill_object_id),
  KEY species (taxon_id),
  KEY external_db (external_db_id),
  KEY user (user_id) 

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'kill_object_reason'
#

CREATE TABLE kill_object_reason (

  kill_object_id          INT(10) UNSIGNED NOT NULL,
  reason_id               INT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (kill_object_id,reason_id),
  KEY kill_object (kill_object_id),
  KEY reason (reason_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'reason'
#

CREATE TABLE reason (

  reason_id               INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  reason_description      VARCHAR(50), 
  why                     TEXT,

  PRIMARY KEY (reason_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'kill_object_analysis'
#

CREATE TABLE kill_object_analysis (

  kill_object_id      INT(10) UNSIGNED NOT NULL,
  analysis_id         INT(10) UNSIGNED NOT NULL, 

  PRIMARY KEY (kill_object_id,analysis_id),
  KEY kill_object (kill_object_id),
  KEY analysis (analysis_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'analysis'
#

CREATE TABLE analysis (

  analysis_id                 SMALLINT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  logic_name                  VARCHAR(40) NOT NULL,
  description                 TEXT,
  program                     VARCHAR(80),

  PRIMARY KEY (analysis_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'external_db'
#

CREATE TABLE external_db (

  external_db_id              SMALLINT UNSIGNED NOT NULL,
  db_name                     VARCHAR(28) NOT NULL,
  db_release                  VARCHAR(255),
  status                      ENUM('KNOWNXREF','KNOWN','XREF','PRED','ORTH',
                                   'PSEUDO')
                              NOT NULL,
  dbprimary_acc_linkable      BOOLEAN DEFAULT 1 NOT NULL,
  display_label_linkable      BOOLEAN DEFAULT 0 NOT NULL,
  priority                    INT NOT NULL,
  db_display_name             VARCHAR(255),
  type                        ENUM('ARRAY', 'ALT_TRANS', 'MISC', 'LIT', 'PRIMARY_DB_SYNONYM'),
  secondary_db_name           VARCHAR(255) DEFAULT NULL,
  secondary_db_table          VARCHAR(255) DEFAULT NULL,

  PRIMARY KEY (external_db_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;


################################################################################
#
# Table structure for table 'species'
#

CREATE TABLE species (

  taxon_id                    int(10) unsigned NOT NULL,
  name                        varchar(255) NOT NULL,
  name_class                  varchar(50) NOT NULL, 

  PRIMARY KEY (taxon_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'species_allowed'
#

CREATE TABLE species_allowed (

  taxon_id                    int(10) unsigned NOT NULL, 
  kill_object_id              INT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (taxon_id,kill_object_id),
  KEY species (taxon_id),
  KEY kill_object (kill_object_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'user'
#

CREATE TABLE user (

  user_id                    int(10) unsigned NOT NULL AUTO_INCREMENT, 
  user_name                  varchar(20), 
  full_name                  TEXT,
  email                      varchar(20),
  team_id                    int(10) unsigned NOT NULL,

  PRIMARY KEY (user_id),
  KEY team (team_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'team'
#

CREATE TABLE team (

  team_id                    int(10) unsigned NOT NULL AUTO_INCREMENT,
  team_name                  varchar(50),

  PRIMARY KEY (team_id)
 
) COLLATE=latin1_swedish_ci TYPE=MyISAM;


################################################################################
#
# Table structure for table 'comment'
#

CREATE TABLE comment (

  comment_id              INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
  user_id                 INT(10) UNSIGNED NOT NULL,
  time_added              datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  kill_object_id          INT(10) UNSIGNED NOT NULL,
  message                 TEXT, 
  
  PRIMARY KEY (comment_id),
  KEY user (user_id),
  KEY kill_object (kill_object_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;


