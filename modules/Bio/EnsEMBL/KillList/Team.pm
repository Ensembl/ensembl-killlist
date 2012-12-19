# $Source: /tmp/ENSCOPY-ENSEMBL-KILLLIST/modules/Bio/EnsEMBL/KillList/Team.pm,v $
# $Revision: 1.2 $

package Bio::EnsEMBL::KillList::Team;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::KillList::DBSQL::TeamAdaptor;

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



