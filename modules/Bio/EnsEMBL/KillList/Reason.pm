# $Source: /tmp/ENSCOPY-ENSEMBL-KILLLIST/modules/Bio/EnsEMBL/KillList/Reason.pm,v $
# $Revision: 1.2 $

package Bio::EnsEMBL::KillList::Reason;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::KillList::DBSQL::ReasonAdaptor;

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



