# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::KillList::Reason;

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

  my ($id, $why, $reason_description, $adaptor) =  
	  rearrange([qw(DBID
	                WHY	
                        REASON_DESCRIPTION
                        ADAPTOR
			)],@args);

  $self->dbID               ( $id );
  $self->why                ( $why );
  $self->reason_description ( $reason_description );
  $self->adaptor            ( $adaptor );
  return $self; # success - we hope!
}


sub why {
  my $self = shift;
  $self->{'why'} = shift if ( @_ );
  return $self->{'why'};
}

sub reason_description {
  my $self = shift;
  $self->{'reason_description'} = shift if ( @_ );
  return $self->{'reason_description'};
}

sub _clone_Reason {
  my ($self, $reason) = @_;
  my $newreason = new Bio::EnsEMBL::KillList::Reason;

  $newreason->dbID               ($reason->dbID);
  $newreason->why                ($reason->why);
  $newreason->reason_description ($reason->reason_description);

  return $newreason;
}

1;



