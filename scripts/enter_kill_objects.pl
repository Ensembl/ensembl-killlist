#!/usr/local/ensembl/bin/perl

=pod

=head1 DESCRIPTION

  Notes found at ensembl-doc/pipeline_docs/using_kill_list_database.txt

  This script allows a user to enter a killer,file or accession, and
  reason (along with the dbuser and dbpass). As long as all info
  required can be found in the Mole db, the entry is stored in the
  ensembl_kill_list database.

=head2 Mole database names

  To find the latest Mole dbanmes, do:

  mysql -ugenero -hcbi3 -Dmm_ini -e "select database_name from ini where available='yes' and current = 'yes'"

=head1 OPTIONS

  -dbuser                   User name to access the kill-list database

  -dbpass                   Password for the kill-list database

  -killer                   User name of the 'killer'

  -mole_dbnames             List of existing databases in Mole

  -reasons                  Reason for killing a sequence

  -accession                Accession number of a single sequence to be killed

  -file                     Input file with accession numbers

  [-comments]               Quoated free text to accompany an entry

  [-source_taxon]           Taxonomy name of the species

  [-for_genebuild_species]  List of Taxonomy IDs of species where a sequence has caused problems

  [-for_genebuild_analyses] List of analyses the sequence was used in

=head1 EXAMPLES

  Tag the following optional parameters on to the commandline too:

    -for_genebuild_species, -for_genebuild_analyses

  The command will look something like this:

    perl enter_kill_objects.pl -killer myname -file info.ls  \
      -dbuser ensadmin -dbpass xxx -reasons Repetitive,Short \
      -for_genebuild_species 10090,9606 -for_genebuild_analyses xlaevis_cDNA,Vertrna

=cut

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

use Bio::EnsEMBL::KillList::AnalysisLite;
use Bio::EnsEMBL::KillList::Comment;
use Bio::EnsEMBL::KillList::KillObject;
use Bio::EnsEMBL::KillList::Reason;
use Bio::EnsEMBL::KillList::Sequence;
use Bio::EnsEMBL::KillList::Species;
use Bio::EnsEMBL::KillList::Team;
use Bio::EnsEMBL::KillList::User;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;

use Bio::EnsEMBL::ExternalData::Mole::Accession;
use Bio::EnsEMBL::ExternalData::Mole::DBXref;
use Bio::EnsEMBL::ExternalData::Mole::Description;
use Bio::EnsEMBL::ExternalData::Mole::Entry;
use Bio::EnsEMBL::ExternalData::Mole::EntryArchive;
use Bio::EnsEMBL::ExternalData::Mole::Taxonomy;
use Bio::EnsEMBL::ExternalData::Mole::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning);


#===============================
#Modify things before running:

# check these are the latest versions:
my @mole_dbnames; # = ('refseq_26','uniprot_12_6','embl_92','embl_89','refseq_25','uniprot_12_5','uniprot_9_3');
# you just need the refseq, embl, emnew and uniprot databases
# the order they are entered in here will determin the order they are searched

#No custom modification should be needed below this line
#===============================

# # # # # #
#
# Set-up
#
# # # # # #

$| = 1; # disable buffering

my (
        $dbname,
        $dbhost,
        $dbuser,
        $dbport,
        $dbpass,
        $file, 
        $accession,
        $user_name,
        $source_taxon,
        @reasons,
        @comments,
        @for_genebuild_species,
        @for_genebuild_analyses,
        );

# kill_list database
$dbname = 'ba1_ensembl_kill_list';
$dbhost = 'genebuild6';
$dbuser = 'ensadmin';
$dbport = 3306, 
$dbpass = undef;

# Mole database
my $mole_dbhost = 'cbi3';
my $mole_dbuser = 'genero';
my $mole_dbport = 3306;

my @not_stored;
my @stored;

GetOptions( 'dbname=s'                 => \$dbname,
            'dbuser=s'                 => \$dbuser,
            'dbhost=s'                 => \$dbhost,
            'dbport=s'                 => \$dbport,
            'dbpass=s'                 => \$dbpass,
            'mole_dbnames=s'           => \@mole_dbnames,
            'file=s'                   => \$file,
            'accession=s'              => \$accession,
            'killer|user=s'            => \$user_name,
            'source_taxon=s'           => \$source_taxon,
            'reasons=s'                => \@reasons,
            'comments=s'               => \@comments,
            'for_genebuild_species=s'  => \@for_genebuild_species,
            'for_genebuild_analyses=s' => \@for_genebuild_analyses, );


# check db variables
if ( !defined($dbname) || !defined($dbuser) || !defined($dbhost) || !defined($dbport)){ 
  die "ERROR: Please set dbhost (-hdbost), dbname (-dbname), dbport (-dbport), dbpass (-dbpass) and dbuser (-dbuser)\n";
}
if ( !defined($dbpass)){ 
  die "ERROR: Please set -dbpass <XXXXX> \n"; 
}

print "You're writing to kill list database : $dbname \@ $dbhost \n" ; sleep(3);


if ( !defined($file) && !defined $accession ) {
  die "Please enter accession or file name, with each line containing accession_version acession molecule_type sequence description\n";
}

if ( defined $file && defined $accession) {
  die "Enter either accession OR file. Not both.\n";
}

if (!@reasons) {
  die "ERROR: Please set at least one reason for this entry\n";
}

if (!@mole_dbnames) { 
  
  throw "Please enter a list of -mole_dbnames\n". 
      "You get the latest list with : \n\tmysql -ugenero -hcbi3 -Dmm_ini -e".
      " \"select database_name from ini where available=\'yes\' and current = \'yes\'\"" ; 
  

}

# split up the arrays
if (scalar(@reasons)) {
  @reasons = split(/,/,join(',',@reasons));
}
if (scalar(@for_genebuild_species)) {
  @for_genebuild_species = split(/,/,join(',',@for_genebuild_species));
}
if (scalar(@for_genebuild_analyses)) {
  @for_genebuild_analyses = split(/,/,join(',',@for_genebuild_analyses));
}
if (scalar(@mole_dbnames)) {
  @mole_dbnames = split(/,/,join(',',@mole_dbnames));
  foreach my $mdb (@mole_dbnames) {
    if ($mdb =~ /mushroom/i) {
      throw("Only enter RefSeq, UniProt and EMBL database names from Mole");
    }
  }
}

# connect to kill_list db
my $db = Bio::EnsEMBL::KillList::DBSQL::DBAdaptor->new(
        '-dbname' => $dbname,
        '-host'   => $dbhost,
        '-user'   => $dbuser,
        '-port'   => $dbport,
        '-pass'   => $dbpass,
);

# connect to mole dbs 
my @mole_dbs;
foreach my $mole_dbname (@mole_dbnames) {
  my $db = Bio::EnsEMBL::ExternalData::Mole::DBSQL::DBAdaptor->new(
        '-dbname' => $mole_dbname,
        '-host'   => $mole_dbhost,
        '-user'   => $mole_dbuser,
        '-port'   => $mole_dbport,
  );
  push @mole_dbs, $db;
}
print "\nConnected to Mole databases. Now searching for accessions in Mole...\n";

# get Kill list adaptors
my $analysis_adaptor = $db->get_AnalysisLiteAdaptor();
my $kill_adaptor = $db->get_KillObjectAdaptor();
my $reason_adaptor = $db->get_ReasonAdaptor();
my $sequence_adaptor = $db->get_SequenceAdaptor();
my $species_adaptor = $db->get_SpeciesAdaptor();
my $user_adaptor = $db->get_UserAdaptor();

my $user = get_check_user($user_adaptor, $user_name, 1);

my @accessions;
my @evidence_to_store;
if (defined $file) {
  open(INFILE, "<$file") or die ("Can't read $file $! \n");
  while(<INFILE>){
    chomp;
    my @fields = split('\s+', $_); 
    my $accession_version = $fields[0];
  
    # this is extra stuff that we don't use
    # my $accession = $fields[1];
    # my $molecule_type = $fields[2];
    # my $sequence = $fields[3];
    # my $description = $fields[4];
    # my $cropped_accession = $accession;
    # $cropped_accession =~ s/\.\d+//;
    # my $accession_to_store = $cropped_accession;
    push @accessions, $accession_version;
  }
  close INFILE;
} elsif (defined $accession) {
  push @accessions, $accession;
}


ACC: foreach my $accession_version (@accessions) {
print STDERR "DOING $accession_version\n";
  # # # 
  # Fetch the Entry from Mole db
  # # #
  my $mole_entry;
  my $from_database;
  if ($accession_version =~ m/\.\d/) {
    #accession has a version
    foreach my $db (@mole_dbs) {
      my $ea;
      if ($db->dbc->dbname() eq 'uniprot_archive') {
        $ea = $db->get_EntryArchiveAdaptor();
      } else {
        $ea = $db->get_EntryAdaptor();
      }
      $mole_entry = $ea->fetch_by_accession_version($accession_version);
      $from_database = $db->dbc->dbname();
      last if defined $mole_entry;
    }
  } else {
    #accession has no version 
    print "ACCESSION has no version \n" ;  
    # get by accession 
    MOLE: foreach my $db (@mole_dbs) {
      # we can't do this call for archive as it hase a different schema
      # with no accession table 
      next MOLE if ($db->dbc->dbname eq 'uniprot_archive');

      my $acc_obj = $db->get_AccessionAdaptor->fetch_by_accession($accession_version) ;  
      if (defined $acc_obj) {
        $mole_entry = $db->get_EntryAdaptor->fetch_by_dbID($acc_obj->entry_id) ; 
      }
      $from_database = $db->dbc->dbname();
      last MOLE if defined $mole_entry;
    } 

#    if (!defined $mole_entry) {
#      INCREMENT_VERS: for (my $i=1; $i<5; $i++) {
#        foreach my $db (@mole_dbs) {
#          my $ea;
#          if ($db->dbc->dbname() eq 'uniprot_archive') {
#            $ea = $db->get_EntryArchiveAdaptor();
#          } else {
#            $ea = $db->get_EntryAdaptor();
#          }
#          $mole_entry = $ea->fetch_by_accession_version($accession_version.".$i");
#          $from_database = $db->dbc->dbname();
#          last INCREMENT_VERS if defined $mole_entry;
#  
#        }
#      }
#    }

  } # accession has no version  
  if (!defined $mole_entry) {
    push @not_stored, $accession_version;
    warning("Unable to fetch entry : $accession_version from mole");
    next ACC;
  }

  # Get additional info

  # accession
  my $accession_to_store; 
  if ($from_database eq 'uniprot_archive') {
    $accession_to_store = $mole_entry->name;
  } else {
    $accession_to_store = $mole_entry->accession_obj->accession;
  }
  if (!defined $accession_to_store) {
    throw("No accession_to_store for $accession_version");
  }

  # molecule type
  my $mol_type = $mole_entry->molecule_type;  

  # taxonomy 
  my $source_taxon_id; 
  if ($mole_entry->taxonomy_obj) {
    $source_taxon_id = $mole_entry->taxonomy_obj->ncbi_tax_id; 
  } elsif ($mole_entry->name =~ /HUMAN/) {
    $source_taxon_id = 9606;
  } elsif ($mole_entry->name =~ /MOUSE/) {
    $source_taxon_id = 10090;
  }

  # accession version
  my $version = $mole_entry->accession_version;
  if (!defined $version) {
    warning("No version for $accession_version");
  }
 
  # description
  my $description;
  if (defined $mole_entry->description_obj && defined $mole_entry->description_obj->description) {
    $description = $mole_entry->description_obj->description;
  } else {
    $description = 'No description available';
  }

  # sequence
  my $sequence = $mole_entry->sequence_obj->sequence;
  my $sequence_obj = Bio::EnsEMBL::KillList::Sequence->new(
              -sequence => $sequence);

  # check we have mol_type
  if (!defined $mol_type) {
    throw("-mol_type not defined");
  } elsif ($mol_type =~ m/protein/i) {
    $mol_type = 'protein';
  } elsif ($mol_type =~ m/cDNA/) {
    $mol_type = 'cDNA';
  } elsif ($mol_type =~ m/mrna/i) {
    $mol_type = 'cDNA';
  } elsif ($mol_type =~ m/est/i) {
    $mol_type = 'EST';
  } elsif ($mol_type =~ /genomic DNA/ || 
           $mol_type =~ /unassigned DNA/ ||
           $mol_type =~ /DNA/ ||
           $mol_type =~ /ss-DNA/ ||
           $mol_type =~ /RNA/ ||
           $mol_type =~ /genomic RNA/ ||
           $mol_type =~ /ds-RNA/ ||
           $mol_type =~ /ss-cRNA/ ||
           $mol_type =~ /ss-RNA/ ||
           $mol_type =~ /tRNA/ ||
           $mol_type =~ /rRNA/ ||
           $mol_type =~ /snoRNA/ ||
           $mol_type =~ /snRNA/ ||
           $mol_type =~ /scRNA/ ||
           $mol_type =~ /pre-RNA/ ||
           $mol_type =~ /other RNA/ ||
           $mol_type =~ /other DNA/ ||
           $mol_type =~ /unassigned RNA/ ||
           $mol_type =~ /viral cRNA/ ||
           $mol_type =~ /cRNA/ ) {
    warning("-mol_type *$mol_type* entered is unusual. Usually we see 'protein', 'cDNA' or 'mRNA' or EST for $accession_version");
  } else {
    throw("-mol_type *$mol_type* entered is not valid for $accession_version");
  }


 # check we have external_db
  my $external_db_id;
  if ($from_database =~ 'embl') {
    $external_db_id = 700;
  } elsif ($from_database =~ 'uniprot') {
    $external_db_id = 2200; #Uniprot/SWISSPROT
  } elsif ($from_database =~ 'refseq' && $mol_type ne 'protein') {
    $external_db_id = 1800; #RefSeq_dna
  } elsif ($from_database =~ 'refseq') {
    $external_db_id = 1810; #RefSeq_peptide
  } else {
    throw("External_db not not found");
  }

 # check we have source_taxon_id
  if (defined $source_taxon_id) {
    $source_taxon = get_check_source_taxon($species_adaptor, $source_taxon_id, 0);
  } else {
    throw("Source_taxon_id not defined");
  }
 
  # check we have a description
  if (!defined $description) {
    warning("No description entered");
  }
  
  
  # get an array of species, analyses and reasons
  my (@species_allowed_objs, @reasons_objs, @analyses_allowed_objs);
  #reasons
  my %uniq_reasons;
  foreach my $keyword (@reasons) {
    $uniq_reasons{$keyword} = 1;
  }
  foreach my $keyword (keys %uniq_reasons) {
    push @reasons_objs, get_check_reason($reason_adaptor, $keyword, 0);
  }
  #species_allowed
  my %uniq_spp;
  if (scalar(@for_genebuild_species)) {
    foreach my $id (@for_genebuild_species) {
      $uniq_spp{$id} = 1;
    }
    foreach my $id (keys %uniq_spp) {
      push @species_allowed_objs, get_check_source_taxon($species_adaptor, $id, 0);
    }
  }
  #analyses_allowed
  my %uniq_analyses;
  if (scalar(@for_genebuild_analyses)) {
    foreach my $logic (@for_genebuild_analyses){
      $uniq_analyses{$logic} = 1;
    }
    foreach my $logic (keys %uniq_analyses) {
      push @analyses_allowed_objs, $analysis_adaptor->fetch_by_logic_name($logic);
    }
  }

  # Add a comment to the entry
  my $message;
  my @comment_objs; 
  if (scalar(@comments)) {
    $message = join(' ', @comments);
    my $comment_obj = Bio::EnsEMBL::KillList::Comment->new(
                         -user    => $user,
                         -message => $message);
    push @comment_objs, $comment_obj;
  } else {
    #$message = "No comment added";
  }

  my $new_evidence = Bio::EnsEMBL::KillList::KillObject->new(
                                           -taxon            => $source_taxon,
                                           -user             => $user,
                                           -mol_type         => $mol_type,
                                           -accession        => $accession_to_store,
                                           -version          => $version,
                                           -external_db_id   => $external_db_id,
                                           -description      => $description,
                                           -reasons          => \@reasons_objs,
                                           -analyses         => \@analyses_allowed_objs,
                                           -comments         => \@comment_objs,
                                           -species_allowed  => \@species_allowed_objs,
                                          );
  if (defined $sequence_obj) {
    #print STDERR "have sequence\n".$sequence_obj->sequence."\n"; 
    $new_evidence->sequence( $sequence_obj );
  } else {
    warning("No sequence for $accession_to_store");
  }
  push @evidence_to_store, $new_evidence;

}


print STDERR "Have ".scalar(@evidence_to_store)." new kill_list objects to store\n";
foreach my $new_evidence (@evidence_to_store) {
  my $evidence_dbID;
  print STDERR "Storing new evidence: \n".
               "  user             : ".$new_evidence->user->dbID    ."\n".
               "  accession        : ".$new_evidence->accession     ."\n".
               "  version          : ".$new_evidence->version       ."\n".
               "  mol_type         : ".$new_evidence->mol_type      ."\n".
               "  taxon            : ".$new_evidence->taxon->dbID   ."\n".
               "  external_db_id   : ".$new_evidence->external_db_id."\n".
               "  sequence         : ".$new_evidence->sequence->sequence      ."\n".
               "  description      : ".$new_evidence->description   ."\n";

  eval {
    $evidence_dbID = $kill_adaptor->store($new_evidence, 0, 1);
  };
  if ($@) {
    push @not_stored, $new_evidence->accession;
    warning("Unable to store ".$new_evidence->accession."\n".$@); 
  } else {
    push @stored,$new_evidence->accession;
    print_stored($db, $evidence_dbID);
  }
}

print "\nStored accessions:\n==================\n";
foreach my $s (@stored) {
    print "$s\n";
}
print "\nAccessions not stored:\n======================\n";
foreach my $ns (@not_stored) {
  print "$ns\n";
}


sub get_check_user {
  my ($user_adaptor, $username, $check) = @_;
  my $user_id;

  if ($check) {
    #print STDERR "> Checking that -user_name exists in database... ";
    
    # make sure user name exists in database
    my $existing_users = $user_adaptor->fetch_all();
    my $user_ok;
    foreach my $user (@$existing_users) {
      if ($username eq $user->user_name ) {
        $user_ok = 1;
        last;
      }
    }
    if (defined $user_ok) {
      $user_id = $user_adaptor->get_dbID_from_name($username);
    } else {
      throw("User does not exist in database. Name entered should be your email address \n".
            "before the \@ .eg. ms53");
    }
  }
  my $user = $user_adaptor->fetch_by_dbID($user_id);
  return $user;
}

sub get_check_source_taxon {
  my ($species_adaptor, $source_taxon_id, $check) = @_;

  if ($check) {
    #print STDERR "> Checking that -source_taxon_id exists in database... ";
  
    # make sure taxon_id exists in database
    my $existing_ids = $species_adaptor->fetch_all();
    my $taxon_ok;
    foreach my $taxon (@$existing_ids) {
      if ( $source_taxon_id == $taxon->dbID ) {
        $taxon_ok = 1;
        print STDERR "-source_taxon_id found\n";
        last;
      }
    }
    my $taxon_id;
    if (!defined $taxon_ok) {
      throw("Taxon_id does not exist in database.");   
    }
  }
  my $species = $species_adaptor->fetch_by_dbID($source_taxon_id);
  return $species;
}
 
sub get_check_reason {
  my ($reason_adaptor, $keyword, $check) = @_;

  if ($check) {
    #print STDERR "> Checking that -reason exists in database...  ";

    # make sure reason_id exists in database
    my $existing = $reason_adaptor->fetch_all();
    my $reason_ok;
    foreach my $r (@$existing) {
      if ( $keyword eq $r->why ) {
        $reason_ok = 1;
        print STDERR "-reason found\n";
        last;
      }
    }
    my $reason_id;
    if (!defined $reason_ok) {
      throw("Reason does not exist in database.");
    }
  }
  my $reason = $reason_adaptor->fetch_by_why($keyword); 
  return $reason;
}

sub print_stored {
  my ($db, $evidence_dbID) = @_;

  print STDERR "  Species_allowed  ->\n";
  foreach my $species (@{$db->get_SpeciesAdaptor->fetch_all_by_KillObject($kill_adaptor->fetch_by_dbID($evidence_dbID))}) {
    print STDERR "                   : ".$species->name."\n";
  }
  print STDERR "  Analyses_allowed ->\n ";
  foreach my $analysis (@{$db->get_AnalysisLiteAdaptor->fetch_all_by_KillObject($kill_adaptor->fetch_by_dbID($evidence_dbID))}) {
    print STDERR "                   : ".$analysis->logic_name."\n";
  }
  print STDERR " Reasons          ->\n";
  foreach my $reason (@{$db->get_ReasonAdaptor->fetch_all_by_KillObject($kill_adaptor->fetch_by_dbID($evidence_dbID))}) {
    print STDERR "                   : ".$reason->why."\n";
  }
  print STDERR "  Comments         ->\n";
  foreach my $comment (@{$db->get_CommentAdaptor->fetch_all_by_KillObject($kill_adaptor->fetch_by_dbID($evidence_dbID))}) {
    print STDERR "                   : ".$comment->message."\n";
  }
}
