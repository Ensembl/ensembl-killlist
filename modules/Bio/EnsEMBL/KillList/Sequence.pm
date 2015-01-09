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

package Bio::EnsEMBL::KillList::Sequence;

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

  my ($kill_obj_id, $sequence, $adaptor) =  
	  rearrange([qw(DBID
	                SEQUENCE
                        ADAPTOR
			)],@args);

  $self->dbID      ( $kill_obj_id ) if ( defined $kill_obj_id );
  $self->sequence  ( $sequence );
  $self->adaptor   ( $adaptor );
  return $self; # success - we hope!
}


sub sequence {
  my $self = shift;
  $self->{'sequence'} = shift if ( @_ );
  return $self->{'sequence'};
}

sub _clone_Sequence {
  my ($self, $sequence) = @_;
  my $newsequence = new Bio::EnsEMBL::KillList::Sequence;

  if ( defined $sequence->dbID ) {
    $newsequence->dbID($sequence->dbID);
  }
  if ( defined $sequence->sequence ){
    $newsequence->sequence($sequence->sequence);
  }

  return $newsequence;
}

1;



