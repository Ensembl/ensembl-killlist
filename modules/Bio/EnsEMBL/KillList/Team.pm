# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::KillList::Team;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

@ISA = qw(Bio::EnsEMBL::Storable);


sub new {
  my($class,@args) = @_;

  my $self = bless {},$class;

  my ($id, $team_name, $adaptor) =  
	  rearrange([qw(DBID
	                TEAM_NAME	
                        ADAPTOR
			)],@args);

  $self->dbID      ( $id );
  $self->team_name ( $team_name );
  $self->adaptor   ( $adaptor );
  return $self; # success - we hope!
}


sub team_name {
  my $self = shift;
  $self->{'team_name'} = shift if ( @_ );
  return $self->{'team_name'};
}

sub _clone_Team {
  my ($self, $team) = @_;
  my $newteam = new Bio::EnsEMBL::KillList::Team;

  if ( defined $team->dbID ) {
    $newteam->dbID($team->dbID);
  }
  if ( defined $team->team_name ){
    $newteam->team_name($team->team_name);
  }

  return $newteam;
}

1;



