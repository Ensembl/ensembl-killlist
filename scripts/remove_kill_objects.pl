#!/usr/bin/env perl

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script allows a user to remove an entry (or entries)
# from the ensembl_kill_list database if we decide that we 
# would like the entries to be used in future genebuilds.
# This script may also be useful when entries were accidentally
# added to the database.

# NOTE: When removing an entry from the database, the entry's 
# status is simply updated to 'REMOVED'. The entry itself, and 
# all associated information, is not actually deleted from the
#  database.

# When doing a remove, the accession VERSION is NOT TAKEN INTO
# ACCOUNT. This is because the generation of a kill-list also
# strips off the versions.

# The command will look something like this:

use strict;
use warnings;
use Getopt::Long;
#use Data::Dumper;
use Bio::EnsEMBL::KillList::KillObject;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning);

# ensembl-killlist/modules/Bio/EnsEMBL/KillList/DBSQL/KillObjectAdaptor.pm

$| = 1; # disable buffering

my (
        $dbname,
        $dbhost,
        $dbuser,
        $dbport,
        $dbpass,
        $file, 
        $accession,
        );

# kill_list database
$dbname = undef ;
$dbhost = undef ;
$dbuser = undef ;
$dbport = 3306, 

&GetOptions(
        'dbname=s'                 => \$dbname,
        'dbuser=s'                 => \$dbuser,
        'dbhost=s'                 => \$dbhost,
        'dbport=s'                 => \$dbport,
        'dbpass=s'                 => \$dbpass,
        'file=s'                   => \$file,
        'accession=s'              => \$accession,
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

# connect to kill_list db
my $db = Bio::EnsEMBL::KillList::DBSQL::DBAdaptor->new(
        '-dbname' => $dbname,
        '-host'   => $dbhost,
        '-user'   => $dbuser,
        '-port'   => $dbport,
        '-pass'   => $dbpass,
);

# get Kill list adaptors
my $kill_adaptor = $db->get_KillObjectAdaptor();

my @accessions;
if (defined $file) {
  open(INFILE, "<$file") or die ("Can't read $file $! \n");
  while(<INFILE>){
    chomp;
    my @fields = split('\s+', $_); 
    my $accession_version = $fields[0];
    push @accessions, $accession_version;
  }
  close INFILE;
} elsif (defined $accession) {
  push @accessions, $accession;
}

# one by one, remove these items. This means:
# First, take all existing entries and update is_current to '0'
# The re-store this object with status = 'REMOVED'
foreach my $accession_version (@accessions) {
  # strip off the version
  my $no_version = $accession_version;
  $no_version =~ s/\.\d+//;

  # do a full fetch
  my $kill_object = $kill_adaptor->fetch_by_accession($no_version,1);
  print STDERR "Fetched $no_version fom database:\n";
  #  print Dumper($kill_object);
  print_stored($db,$kill_object->dbID);

  # remove
  print STDERR "Removing...\n";
  my $new_kill_obj_dbID = $kill_adaptor->remove($kill_object); 
  my $new_kill_object = $kill_adaptor->fetch_by_dbID($new_kill_obj_dbID, 1); 
  #  print Dumper($new_kill_object);
  print_stored($db,$new_kill_obj_dbID);
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
