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

=pod 

=head1 NAME

Bio::EnsEMBL::KillList::AnalysisLite.pm - Stores basics of an analysis run

=head1 SYNOPSIS

    my $obj    = new Bio::EnsEMBL::KillList::AnalysisLite(
        -id              => $id,
        -logic_name      => 'SWIRBlast',
        -program         => $program,
        -description     => $description
        );

=head1 DESCRIPTION

Object to store details of an analysis run

=head1 CONTACT

Post questions to the EnsEMBL::Map dev mailing list: <ensembl-dev@ebi.ac.uk>

=head1 METHODS

=cut


package Bio::EnsEMBL::KillList::AnalysisLite;

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

  my ($id, $adaptor, $program, 
      $logic_name, $description) = 

	  rearrange([qw(        dbID
	  			ADAPTOR
				PROGRAM
				LOGIC_NAME
			        DESCRIPTION
				)],@args);

  $self->dbID       ( $id );
  $self->analysis_id ( $id );
  $self->adaptor    ( $adaptor );
  $self->program    ( $program );
  $self->logic_name ( $logic_name );
  $self->description( $description );
  return $self; # success - we hope!
}

sub analysis_id {
  my $self = shift;
  $self->{'analysis_id'} = shift if ( @_ );
  return $self->{'analysis_id'};
}

sub program {
  my $self = shift;
  $self->{'program'} = shift if ( @_ );
  return $self->{'program'};
}

sub logic_name {
  my $self = shift;
  $self->{'logic_name'} = shift if ( @_ );
  return $self->{'logic_name'};
}

sub description {
  my $self = shift;
  $self->{'description'} = shift if ( @_ );
  return $self->{'description'};
}

sub _clone_Analysis {
  my ($self, $analysis) = @_;
  my $newanalysis = new Bio::EnsEMBL::KillList::AnalysisLite;

  $newanalysis->dbID         ($analysis->dbID);
  $newanalysis->logic_name   ($analysis->logic_name);
  $newanalysis->program      ($analysis->program);
  $newanalysis->description  ($analysis->description);

  return $newanalysis;
}

1;



