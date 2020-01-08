# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
use warnings;

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
