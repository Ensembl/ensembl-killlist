#!/usr/bin/perl -w

# This script allows a user to enter a killer,file or accession, and reason
# (along with the dbuser and dbpass). As long as all info required
# can be found in the Mole db, the entry is stored in the 
# ensembl_kill_list database. 


# Tag the following optional parameters on to the commandline too:
# -for_genebuild_species, -for_genebuild_analyses, -comment
 
# The command will look something like this:
#  perl enter_kill_objects.pl -killer 4 -file info.ls \
#  -dbuser ensadmin -dbpass xxx -reasons Repetitive,Short -for_genebuild_species \
#  10090,9606 -for_genebuild_analyses xlaevis_cDNA,Vertrna -comment 'this is bad'


use strict;
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

use Bio::EnsEMBL::Mole::Accession;
use Bio::EnsEMBL::Mole::DBXref;
use Bio::EnsEMBL::Mole::Description;
use Bio::EnsEMBL::Mole::Entry;
use Bio::EnsEMBL::Mole::Taxonomy;
use Bio::EnsEMBL::Mole::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning);


#===============================
#Modify things before running: 

# check these are the latest versions:
my @mole_dbnames = ('embl_90','refseq_22','uniprot_10_4','embl_89','refseq_21','uniprot_10_3'); 

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
        @for_genebuild_species,
        @for_genebuild_analyses,
        );

# kill_list database
$dbname = 'ba1_ensembl_kill_list';
$dbhost = 'genebuild6';
$dbuser = 'ensro';
$dbport = 3306, 

# Mole database
my $mole_dbhost = 'cbi3';
my $mole_dbuser = 'genero';
my $mole_dbport = 3306;


&GetOptions(
        'dbname=s'                 => \$dbname,
        'dbuser=s'                 => \$dbuser,
        'dbhost=s'                 => \$dbhost,
        'dbport=s'                 => \$dbport,
        'dbpass=s'                 => \$dbpass,
        'mole_dbnames=s'           => \@mole_dbnames,
        'file=s'                   => \$file,
        'accession=s'              => \$accession,
        'killer=s'                 => \$user_name,
        'source_taxon=s'           => \$source_taxon,
        'reasons=s'                => \@reasons,
        'for_genebuild_species=s'  => \@for_genebuild_species,
        'for_genebuild_analyses=s' => \@for_genebuild_analyses,
);


# check db variables
if ( !defined($dbname) || !defined($dbuser) || !defined($dbhost) || 
     !defined($dbport) || !defined($dbpass)) {
  die "ERROR: Please set dbhost (-hdbost), dbname (-dbname), dbport (-dbport), dbpass (-dbpass) and dbuser (-dbuser)\n";
}

if ( !defined($file) && !defined $accession ) {
  die "Please enter accession or file name, with each line containing accession_version acession molecule_type sequence description\n";
}

if ( defined $file && defined $accession) {
  die "Enter either accession OR file. Not both.\n";
}

if (!@reasons) {
  die "ERROR: Please set at least on reason for this entry\n";
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
  my $db = Bio::EnsEMBL::Mole::DBSQL::DBAdaptor->new(
        '-dbname' => $mole_dbname,
        '-host'   => $mole_dbhost,
        '-user'   => $mole_dbuser,
        '-port'   => $mole_dbport,
  );
  push @mole_dbs, $db;
}


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
    my @fields = split('\t', $_); 
    # or split('\s+', $_) might be better
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


foreach my $accession_version (@accessions) {
  # # # 
  # Fetch the Entry from Mole db
  # # #
  my $mole_entry;
  my $from_database;
  if ($accession_version =~ m/\.\d/) {
    #accession has a version
    foreach my $db (@mole_dbs) {
      my $ea = $db->get_EntryAdaptor();
      $mole_entry = $ea->fetch_by_accession_version($accession_version);
      $from_database = $db->dbc->dbname();
      last if defined $mole_entry;
    }
  } else {
    #accession has no version
    foreach my $db (@mole_dbs) {
      my $ea = $db->get_EntryAdaptor();
      $mole_entry = $ea->fetch_by_name($accession_version);
      $from_database = $db->dbc->dbname();
      last if defined $mole_entry;
    }
  }
  if (!defined $mole_entry) {
    throw("Unable to fetch entry from mole");
  }

  # Get additional info
  my $accession_to_store = $mole_entry->accession_obj->accession;
  if (!defined $accession_to_store) {
    throw("No accession_to_store for $accession_version");
  }
  my $mol_type = $mole_entry->molecule_type;
  my $source_taxon_id = $mole_entry->taxonomy_obj->ncbi_tax_id;
  my $version = $mole_entry->accession_version;
  if (!defined $version) {
    warning("No version for $accession_version");
  }
  my $description;
  if (defined $mole_entry->description_obj && defined $mole_entry->description_obj->description) {
    $description = $mole_entry->description_obj->description;
  } else {
    $description = 'No description available';
  }
  my $sequence = $mole_entry->sequence_obj->sequence;
  my $sequence_obj = Bio::EnsEMBL::KillList::Sequence->new(
              -sequence => $sequence);

  # check we have mol_type
  if (!defined $mol_type) {
    throw("-mol_type not defined");
  } elsif ($mol_type =~ m/protein/i) {
    $mol_type = 'protein';
  } elsif ($mol_type =~ m/cdna/i) {
    $mol_type = 'cDNA';
  } elsif ($mol_type =~ m/mrna/i) {
    $mol_type = 'cDNA';
  } elsif ($mol_type =~ m/rna/i) {
    $mol_type = 'cDNA';
  } elsif ($mol_type =~ m/est/i) {
    $mol_type = 'EST';
  } else {
    throw("-mol_type entered is not valid. Must be 'protein', 'cDNA' or 'mRNA'");
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
  
#  # make comment
#  my $message;
#  my @comment_objs; 
#  if (!scalar(@comment)) {
#    $message = "No comment added"; 
#  } else {
#    $message = join(' ', @comment); 
#    my $comment_obj = Bio::EnsEMBL::KillList::Comment->new(
#                         -user    => $user,
#                         -message => $message);
#    push @comment_objs, $comment_obj;
#  }

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
#                                           -comments         => \@comment_objs,
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
  print STDERR "Storing new evidence: \n".
               "  user             : ".$new_evidence->user->dbID    ."\n".
               "  accession        : ".$new_evidence->accession     ."\n".
               "  version          : ".$new_evidence->version       ."\n".
               "  mol_type         : ".$new_evidence->mol_type      ."\n".
               "  taxon            : ".$new_evidence->taxon->dbID   ."\n".
               "  external_db_id   : ".$new_evidence->external_db_id."\n".
               "  sequence         : ".$new_evidence->sequence->sequence      ."\n".
               "  description      : ".$new_evidence->description   ."\n";
  print Dumper($new_evidence);

  my $evidence_dbID = $kill_adaptor->store($new_evidence, 0, 1);
  print_stored($db, $evidence_dbID);
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
        print STDERR -"user_name found\n";  
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
    print STDERR "                   : ".$analysis->program."\n";
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
