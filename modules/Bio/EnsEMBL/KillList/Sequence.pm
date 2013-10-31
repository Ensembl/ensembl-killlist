
package Bio::EnsEMBL::KillList::Sequence;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::KillList::DBSQL::SequenceAdaptor;

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



