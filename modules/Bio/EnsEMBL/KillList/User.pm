package Bio::EnsEMBL::KillList::User;

use strict;
use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::KillList::DBSQL::UserAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning);

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Storable);


sub new {
  my $caller = shift;

  my $class = ref($caller) || $caller;
  my $self = $class->SUPER::new(@_);

  my ($user_id, $adaptor, $user_name, $full_name, $email, $team) =
      rearrange( ['DBID','ADAPTOR',  'USER_NAME', 'FULL_NAME','EMAIL', 'TEAM'], @_);  

  if (!defined($user_name) || !defined($email) || 
      !defined($full_name) || !$team ) { 
    throw " ERROR: need to set -user_name, -full_name, -email, -team";
  }

  if(!ref($team) || !$team->isa('Bio::EnsEMBL::KillList::Team')) {
    throw('-TEAM argument must be a Bio::EnsEMBL::Team not '.
          $team);
  }
  $self->team      ( $team );
  $self->dbID      ( $user_id );
  $self->adaptor   ( $adaptor );
  $self->user_name ( $user_name );
  $self->full_name ( $full_name );
  $self->email     ( $email );
  return $self;
}

sub user_name {
  my $self = shift;
  $self->{'user_name'} = shift if( @_ );
  return $self->{'user_name'};
}

sub full_name {
  my $self = shift;
  $self->{'full_name'} = shift if( @_ );
  return $self->{'full_name'};
}

sub email {
  my $self = shift;
  $self->{'email'} = shift if( @_ );
  return $self->{'email'};
}

sub team {
  my $self = shift;

  if(@_) {
    my $tm = shift;
    if(defined($tm) && (!ref($tm) || !$tm->isa('Bio::EnsEMBL::KillList::Team'))) {
      throw('-team argument must be a Bio::EnsEMBL::Team');
    }
    $self->{'team'} = $tm;
  }

  return $self->{'team'};
}

sub _clone_User {
  my ($self, $user) = @_;
  my $newuser = new Bio::EnsEMBL::KillList::User(
                -dbID       => $user->dbID,
                -user_name  => $user->user_name,
                -full_name  => $user->full_name,
                -email      => $user->email,
                -team       => Bio::EnsEMBL::KillList::Team->_clone_Team($user->team)
                                            );

#  my $newteam = Bio::EnsEMBL::KillList::Team->_clone_Team($user->team); 
#
#  if ( defined $user->dbID ) {
#    $newuser->dbID($user->dbID);
#  }
#  if ( defined $user->user_name ) {
#    $newuser->user_name($user->user_name);
#  }
#  if ( defined $user->full_name ) {
#    $newuser->full_name($user->full_name);
#  }
#  if ( defined $user->email ) {
#    $newuser->email($user->email);
#  }
#  if ( defined $user->team ) {
#    $newuser->team($newteam);
#  }
  return $newuser;
}

1;

