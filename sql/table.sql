# Tables for ensembl_kill db
#
#


################################################################################
#
# Table structure for table 'object'
#

CREATE TABLE object (

  object_id                   INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
  taxon_id                    int(10) unsigned, 
  mol_type                    ENUM('protein', 'cDNA', 'mRNA') NOT NULL,
  accession                   varchar(20),
  version                     varchar(20),
  external_db_id              int(11), 
  description                 TEXT,
  created                     datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  user_id                     INT(10) UNSIGNED NOT NULL, 

  PRIMARY KEY (object_id),
  KEY species (taxon_id),
  KEY external_db (external_db_id),
  KEY user (user_id) 

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'object_reason'
#

CREATE TABLE object_reason (

  object_id               INT(10) UNSIGNED NOT NULL,
  reason_id               SMALLINT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (object_id,reason_id),
  KEY object (object_id),
  KEY reason (reason_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'reason'
#

CREATE TABLE reason (

  reason_id               SMALLINT(10) UNSIGNED NOT NULL,
  reason                  TEXT,

  PRIMARY KEY (reason_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'object_analysis'
#

CREATE TABLE object_analysis (

  object_id           INT(10) UNSIGNED NOT NULL,
  analysis_id         SMALLINT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (object_id,analysis_id),
  KEY object (object_id),
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

  external_db_id              INT(10) UNSIGNED NOT NULL,
  db_name                     VARCHAR(27) NOT NULL,
  db_release                  VARCHAR(40) NOT NULL,
  status                      ENUM('KNOWNXREF','KNOWN','XREF','PRED','ORTH',
                                   'PSEUDO')
                              NOT NULL,
  dbprimary_acc_linkable      BOOLEAN DEFAULT 1 NOT NULL,
  display_label_linkable      BOOLEAN DEFAULT 0 NOT NULL,
  priority                    INT NOT NULL,
  db_display_name             VARCHAR(255),
  allowed                     BOOLEAN NOT NULL DEFAULT 0,

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
  object_id                   INT(10) UNSIGNED NOT NULL,

  PRIMARY KEY (taxon_id,object_id),
  KEY species (taxon_id),
  KEY object (object_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'user'
#

CREATE TABLE user (

  user_id                     int(10) unsigned NOT NULL,
  user_name                   varchar(20), 
  full_name                   TEXT,
  team_id                    int(10) unsigned NOT NULL,

  PRIMARY KEY (user_id),
  KEY team (team_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;



################################################################################
#
# Table structure for table 'team'
#

CREATE TABLE team (

  team_id                    int(10) unsigned NOT NULL,
  team_name                  varchar(50),

  PRIMARY KEY (team_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;


################################################################################
#
# Table structure for table 'comment'
#

CREATE TABLE comment (

  log_id                  INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
  user_id                 INT(10) UNSIGNED NOT NULL,
  logtime                 datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  object_id               INT(10) UNSIGNED NOT NULL,
  log                     TEXT, 
  
  PRIMARY KEY (log_id),
  KEY user (user_id),
  KEY object (object_id)

) COLLATE=latin1_swedish_ci TYPE=MyISAM;


