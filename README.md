ensembl-killlist

Overview
=======
1. What is the ensembl_kill_list database?
2. Database schema
3. Adding, removing and updating database entries 
4. Adding entries to the ensembl_kill_list database
5. Getting a kill_list from the ensembl_kill_list database
 

1. What is the ensembl_kill_list database?
==
The ensembl_kill_list database is a MySQL database containing information
about certain proteins and cDNAs that we (the genebuilders) have found to
cause problems during the genebuild.

Proteins and cDNAs in this database will not be used during the genebuild
process.


2. Database schema
==
```
                                                    +----------------------+        +----------------------+
                                                    | kill_object_analysis |        |      analysis        |
                                                    +----------------------+        +----------------------+
                                               ____n| kill_object_id       |   ____1| analysis_id          |
                                               |    | analysis_id          |1__|    | logic_name           |
                                               |    +----------------------+        | description          | 
                                               |                                    | program              |
                                               |                                     +----------------------+
                                               | 
                                               |
                                               |     +--------------------+          +--------------------+
                                               |     | kill_object_reason |          |      reason        |
                                               |     +--------------------+          +--------------------+ 
                                               |___n_| kill_object_id     |   ______1| reason_id          |
                                               |     | reason_id          |1__|      | why                | 
                                               |     +--------------------+          | reason_description |  
                                               |                                     +--------------------+
                                               |
                                               |
                                               |     +-----------------+             +-----------------+
                                               |     | species_allowed |             |     species     | 
                                               |     +-----------------+             +-----------------+
                                               |____n| kill_object_id  |   _________1| taxon_id        |
                                               |     | taxon_id        |1__|         | name            |
                                               |     +-----------------+             | name_class      |
                                               |                                      +-----------------+
                                               |
                                               |
                                               |
                          +----------------+   |     +----------------+
                          |  kill_object   |   |     |    sequence    |
                          +----------------+   |     +----------------+
                     ____1| kill_object_id |1__|____1| kill_object_id |
                     |    | taxon_id       |         | sequence       |
 +----------------+  |    | mol_type       |         +----------------+
 |   comment      |  |    | accession      |
 +----------------+  |    | version        |
 | comment_id     |  |    | external_db_id |1___     +------------------------+  
 | kill_object_id |n_|    | description    |    |    |      external_db       |
 | user_id        |1_____1| user_id        |__  |    +------------------------+
 | time_added     |   |   +----------------+ |  |___1| external_db_id         |
 | message        |   |                      |       | db_name                |
 +----------------+   |                      |       | db_release             |
                      |                      |       | status                 |
                      |                      |       | dbprimary_acc_linkable |
                      |                      |       | display_label_linkable |
                      |                      |       | priority               |
                      |                      |       | db_display_name        |
                      |                      |       | allowed                |
                      |                      |       +------------------------+
                      |                      |
                      |                      | 
                      |                      |     +-----------+                   +-----------+
                      |                      |     |    user   |                   |   team    |
                      |                      |     +-----------+                   +-----------+
                      |______________________|_____| user_id   |        __________1| team_id   |
                                                   | user_name |        |          | team_name |
                                                   | full_name |        |          +-----------+
                                                   | email     |        |
                                                   | team_id   |n_______|
                                                   +-----------+ 
```

3. Adding, removing and updating database entries
==
When new entries are added to the database, a check is done to see whether an entry with a similar 
accession already exists. If an entry exists, then the union of the two entries is stored under a
new kill_object_id and the entry has a status of 'UPDATED'. (All older entries with the same 
accession will be updated to not_current.) In the case of a completely new entry, the entry will 
have a status of 'CREATED'. 

When removing an entry from the database, the entry's status is simply updated to 'REMOVED'. The 
entry itself, and all associated information, is not actually deleted from the database.

A removed entry can be restored. When this happens, the entry is stored as if it were a completely 
new entry, except that it has status 'RESTORED'.

Note: When the ensembl_kill_list db was first created, there was a bug in the script that added entries to the database. This bug has now been fixed but it means that there may be some older entries in the database where the sequence, description or source_species is incorrect. Some of the entries has been fixed but entries that are no longer in Mole have not been fixed. This should not affect the creation of kill lists for use the pipeline.    

4. Adding entries to the ensembl_kill_list database
==
Currently, all of the Mole and Kill_list_db API is stored in ensembl-personal/ba1/kill_list_db/modules/
so this will need to be added to your PERL5LIB before you can go any further.

A script for adding things to the ensembl_kill_list:
  scripts/enter_kill_objects_from_file.pl

This script currently takes a file containing a list of accessions in the first column. The script 
connects to the Mole databases (EMBL, RefSeq, Uniprot) and looks for this accession in these 
databases. It collects the required information (eg. description, sequence) from the relevant Mole 
database and then writes the entry to the ensembl_kill_list db. The user must enter a user_id 
(eg. -killer ba1) and at least one reason (eg. -reason Viral if there is only one reason, or 
-reason LINE,Riken if there is more than one reason) for killing these accessions. It is also 
possible to tell the script that you only want to kill these accessions for human, or that you 
only want to kill these accessions for TargettedGenewise.  

Options:
*  `-dbname`                     # the db to which your cDNA or protein will be added
*  `-dbuser`                     # database server username
*  `-dbhost`                     # database server
*  `-dbport`                     # 3306
*  `-dbpass`                     # database server username
*  `-mole_dbnames`               # check for latest releases (-hcbi3 -ugenero). Always enter at least one
                                release previous to the latest too, as sometimes things aren't found 
                                in the newest databases.
*  `-file`                       # /path/to/your/file.ls (file of accessions that you want to kill)
*  `-killer`                     # same as your email prefix
*  `-reasons`                    # why you're killing these * 
*  `-for_genebuild_species`      # don't kill for these species. Give taxon_ids. (Add to species_allowed table)
*  `-for_genebuild_analyses`     # don't kill for these analyses. Give logic_names. (Add to kill_object_analysis table)

There is a set list of reasons in the database. You must choose one of these reasons:

 Code            |       Meaning
-----------------|-----------------------------------------------------
 Alu             |       Alu repeats (5 AG/CT 3), subclass of SINEs
 Chimeric_cDNA   |       Predicted Chimeric cDNA
 Chimeric_clone  |       Chimeric clone
 Cytochrome      |       Cytochrome
 Env             |       Similar to Envelope protein
 Gag             |       Similar to Gag-protein
 HiThru          |       High-throughput, low quality
 Hypothetical    |       Hypothetical/putative protein
 L1              |       LINE-1 retrotransposon
 L1_transposable |       LINE-1 transposable element
 LINE            |       Long interspersed nuclear element (repeat)
 Long            |       Long
 Long_intron     |       Long intron
 LTR             |       Long terminal repeat
 Memory          |       Requires too much memory
 None            |       No reason given
 ORF             |       Open reading frame (ORF)
 Other           |       Other
 P40             |       P40
 Partial         |       Fragment/partial
 Pol             |       Similar to Pol protein
 Pro             |       Similar to Pro protein
 Promiscuous     |       Hit too many times
 Repetitive      |       Repetitive/low complexity
 Retained_intron |       Retained intron
 Riken           |       Riken
 RT              |       Reverse transcriptase
 Short           |       Short
 SINE            |       Short interspersed nuclear element (repeat)
 Testis          |       Testis
 Transposable_elements   |       Supports transposable elements
 Transposase     |       Transposase
 Un-genewiseable |       Un-genewiseable - predominantly ACTG
 Viral           |       Viral
 X               |       Too many X

Note that for `-reasons`, `-for_genebuild_species` and `-for_genebuild_analyses` you need to make sure that you enter the
exact string (for `-reason` and `-for_genebuild_analyses`) or correct species number (for` -for_genebuild_species`)
in the command-line, or the script will not find these. Ditto for your `-killer`. This is because these values
have already been entered into the database; your commandline has to match the entries in the database. 

Example command:
  ```
  perl enter_kill_objects_from_file.pl -dbuser dbusername -dbpass xxx -file protein_accession.ls \ 
    -killer userid -reason Chimeric_clone -for_genebuild_species 9606 -for_genebuild_analyses cDNA_update \ 
    -mole_dbnames embl_90,refseq_22,uniprot_10_2,embl_89,refseq_21,uniprot_10_1
 ```



5. Getting a kill_list from the ensembl_kill_list database
==
Some modules that make use of the ensembl_kill_list are:
  BlastMiniGenewise.pm
  TargettedGenewise.pm

Some scripts that make use of the ensembl_kill_list are:
  new_cDNA_update.pl
  prepare_proteome.pl
  record_unmapped_cdnas.pl


What you need:
 1.   Mole and Kill_list_db API
      Currently, all of the Mole and Kill_list_db API is stored in ensembl-personal/ba1/kill_list_db/modules/
      so this will need to be added to your PERL5LIB
 
 2.  /Bio/EnsEMBL/Pipeline/Config/GeneBuild/Databases.pm  
 ```
      GB_KILL_DBHOST             => 'dbserver',
      GB_KILL_DBNAME             => 'kill_list_DB',
      GB_KILL_DBUSER             => 'user',
      GB_KILL_DBPASS             => 'pass',
      GB_KILL_DBPORT             => '3306',
 ```
 
 3. /Bio/EnsEMBL/Pipeline/Config/GeneBuild/KillListFilter.pm 
 ```
      cDNA => {
        FILTER_PARAMS    => {
          -only_mol_type        => 'cDNA',
          -user_id              => undef,
          -from_source_species  => undef,
          -before_date          => undef,
          -having_status        => undef,
          -reasons              => [],
          -for_analyses         => [],
          -for_species          => [],
          -for_external_db_ids  => [],
        }
      },
  ```
What do these options mean? The logic is a bit weird so read carefully.
     * `-only_mol_type`:      only fetch accessions of this molecule type
                              eg. 'cDNA' will return a list of cDNAs to be killed
     * `-user_id`:            only fetch accessions entered by this user
                              eg. 'user1' will return a list of accessions to be killed;
                              all of these accession will have been added to the kill_list_DB by user1
     * `-from_source_species`:only fetch accessions where the cDNA or protein comes from this species
                              eg. '9606' will return a kill list with only human cDNAs or proteins
     * `-before_date`:        only fetch accessions entered into ba1_ensembl_kill_list before this date
                              '2006.10.13' will return a list of accessions that were entered
                              before 13 October 2006
     * `-having_status`:      only fetch accessions having this status in kill_list_DB
                              eg. 'UPDATED' will return a list of accession to be killed;
                              all of these accessions will have current status set to 'UPDATED'
                              if status is not defined, the kill list returned will have all
                              accessions excpet those with a status of 'REMOVED'
     * `-for_external_db_ids`:only fetch accessions from these external databases
                              eg. `['1800','1810']` will return a kill list containing accessions
                              that comes from RefSeq:
                              
                              external db ID | DB name
                              ----:|:-----------------------
                              700  |  EMBL                 
                              1800 |  RefSeq DNA           
                              1810 |  RefSeq peptide       
                              2000 |  UniProtKB/TrEMBL     
                              2200 |  UniProtKB/Swiss-Prot 
     * `-reasons`:            for each of the reasons listed in the config, return a kill list of
                              accessions that were killed for these reasons
                              eg. `['Short']` will return a kill list of cDNAs or proteins that were
                              killed because they were too short
     * `-for_analyses`:       Opposite logic to the above options. For each of these analyses entered 
                              in the config, delete accessions from the kill_list that have an entry in 
                              kill_object_analysis for this analysis. 
                              (The kill_object_analysis table stores accessions which should not be killed
                              for particular analyses).
                              eg. `['cDNA_update']` will return a kill list that does not contain cDNAs
                              or proteins that have an entry in the kill_object_analysis table. Entries 
                              eligible for cDNA_update analysis will not be killed. 
                              (these entries that do not appear on the returned kill list would have been
                              entered with the `-for_genebuild_analyses cDNA_update` option when running
                              enter_kill_objects_from_file.pl)
     * `-for_species`:        As above. For each of these species, delete accessions from
                              the kill_list that have an entry in species_allowed table for this species
                              (The species_allowed table stores accessions which should not be killed for 
                              particular species.)
                              eg. `['9606']` will return a kill list that does not contain cDNAs
                              or proteins that have an entry in the species_allowed table. Mouse entries
                              will not be killed. 
                              (these entries that do not appear on the returned kill list would have been
                              entered with the `-for_genebuild_species 9606` option when running
                              enter_kill_objects_from_file.pl)
       (see also modules/Bio/EnsEMBL/KillList/Filter.pm
       and modules/Bio/EnsEMBL/KillList/KillList.pm)
 
 4.  /Bio/EnsEMBL/Pipeline/Config/GeneBuild/Pmatch.pm 
 
 5.   /Bio/EnsEMBL/Pipeline/Config/GeneBuild/Scripts.pm
 ```
      GB_KILL_LIST   => '',
 ```
