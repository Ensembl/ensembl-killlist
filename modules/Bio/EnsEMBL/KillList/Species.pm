# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::KillList::Species;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::KillList::DBSQL::SpeciesAdaptor;

@ISA = qw(Bio::EnsEMBL::Storable);


sub new {
  my($class,@args) = @_;

  my $self = bless {},$class;

  my ( $taxon_id, $adaptor, $name, $name_class ) = 
      rearrange([qw(TAXON_ID
                    ADAPTOR
                    NAME
                    NAME_CLASS )],@args); 

  $self->taxon_id  ( $taxon_id );
  $self->dbID      ( $taxon_id );
  $self->adaptor   ( $adaptor );
  $self->name      ( $name );
  $self->name_class( $name_class );
  return $self; # success - we hope!
}


sub taxon_id {
  my $self = shift;
  $self->{'taxon_id'} = shift if ( @_ );
  return $self->{'taxon_id'};
}

sub name {
  my $self = shift;
  $self->{'name'} = shift if ( @_ );
  return $self->{'name'};
}

sub name_class {
  my $self = shift;
  $self->{'name_class'} = shift if ( @_ );
  return $self->{'name_class'};
}

sub _clone_Species {
  my ($self, $species) = @_;
  my $newspecies = new Bio::EnsEMBL::KillList::Species;

  $newspecies->dbID       ($species->dbID);
  $newspecies->taxon_id   ($species->taxon_id);
  $newspecies->name       ($species->name);
  $newspecies->name_class ($species->name_class);

  return $newspecies;
}

1;
