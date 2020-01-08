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
package Bio::EnsEMBL::KillList::DBSQL::SpeciesAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::Species;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['species' , 's']);
}

sub _columns {
  my $self = shift;
  return ( 's.taxon_id', 's.name', 's.name_class');
}

sub fetch_all_by_KillObject {
  my $self = shift;
  my $killobject = shift;
  my $sth = $self->prepare(
            "SELECT taxon_id ".
            "FROM species_allowed sa, kill_object_status kos ".
            "WHERE sa.kill_object_id = kos.kill_object_id ".
            "AND sa.kill_object_id = ?");
  $sth->bind_param(1, $killobject->dbID, SQL_INTEGER);
  $sth->execute();
  my @speciesids;
  while (my $id = $sth->fetchrow) {
    push @speciesids, $id;
  }
  $sth->finish();

#  my @obj_ids = map {$_->[0]} @speciesids;
  my @obj_ids = @speciesids;
  my @species_allowed;
  foreach my $id (@obj_ids) {
    my $species_object = $self->fetch_by_dbID($id);
    push @species_allowed, $species_object;
  }
  return \@species_allowed;
}

sub fetch_by_dbID {
  my $self = shift;
  my $taxonid = shift;
  my $constraint = "s.taxon_id = '$taxonid'";
  my ($species_obj) = @{ $self->generic_fetch($constraint) };
  return $species_obj;
}

sub fetch_all {
  my $self = shift;
  my @species = @{ $self->generic_fetch() };
  return \@species; 
}

sub fetch_by_name {
  my $self = shift;
  my $speciesname = shift;
  my $constraint = "s.name = '$speciesname'";
  my ($species_obj) = @{ $self->generic_fetch($constraint) };
  return $species_obj;
}

sub fetch_by_genus {
  my $self = shift;
  my $speciesgenus = shift;
  my $constraint = "s.name like '$speciesgenus %'";
  my @species_objs = @{ $self->generic_fetch($constraint) };
  return \@species_objs;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @out;
  my ( $taxon_id, $name, $name_class );  

  $sth->bind_columns( \$taxon_id, \$name, \$name_class ); 

  while($sth->fetch()) {
    #print STDERR "$taxon_id, $name, $name_class\n";
    push @out, Bio::EnsEMBL::KillList::Species->new(
              -adaptor    => $self,
              -taxon_id   => $taxon_id,
              -dbID       => $taxon_id,
              -name       => $name,
              -name_class => $name_class
              );
  }
  return \@out;
}


1;

