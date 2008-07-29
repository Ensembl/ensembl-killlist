#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::KillList::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::KillList::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
        );


=head1 DESCRIPTION

This object represents the handle for a Kill-List database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


# Let the code begin...


package Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBAdaptor );



sub get_available_adaptors {
 
  print "Getting available adaptors\n";
  my %pairs =  (
      "AnalysisLite" => "Bio::EnsEMBL::KillList::DBSQL::AnalysisLiteAdaptor",
      "Comment"      => "Bio::EnsEMBL::KillList::DBSQL::CommentAdaptor",
      "KillObject"   => "Bio::EnsEMBL::KillList::DBSQL::KillObjectAdaptor",
      "Reason"       => "Bio::EnsEMBL::KillList::DBSQL::ReasonAdaptor",
      "Sequence"     => "Bio::EnsEMBL::KillList::DBSQL::SequenceAdaptor",
      "Species"      => "Bio::EnsEMBL::KillList::DBSQL::SpeciesAdaptor",
      "Team"         => "Bio::EnsEMBL::KillList::DBSQL::TeamAdaptor",
      "User"         => "Bio::EnsEMBL::KillList::DBSQL::UserAdaptor",
        );
  return (\%pairs);
}
 

1;
