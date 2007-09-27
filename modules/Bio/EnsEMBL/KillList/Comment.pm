package Bio::EnsEMBL::KillList::Comment;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Storable;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::KillList::DBSQL::CommentAdaptor;

@ISA = qw(Bio::EnsEMBL::Storable);


sub new {
  my($class,@args) = @_;

  my $self = bless {},$class;

  my ( $comment_id, $adaptor, $user, $time_added, $kill_object_id, $message ) = 
      rearrange([qw(DBID
                    ADAPTOR
                    USER
                    TIME_ADDED 
                    KILL_OBJECT_ID
                    MESSAGE )],@args); 

  if(!ref($user) || !$user->isa('Bio::EnsEMBL::KillList::User')) {
    throw('-USER argument must be a Bio::EnsEMBL::User not '.
          $user);
  }
  $self->user            ( $user );
  $self->dbID            ( $comment_id );
  $self->adaptor         ( $adaptor);
  $self->time_added      ( $time_added );
  $self->kill_object_id  ( $kill_object_id );
  $self->message         ( $message );
  return $self; # success - we hope!
}

sub user {
  my $self = shift;

  if(@_) {
    my $usr = shift;
    if(defined($usr) && (!ref($usr) || !$usr->isa('Bio::EnsEMBL::KillList::User'))) {
      throw('user argument must be a Bio::EnsEMBL::User');
    }
    $self->{'user'} = $usr;
  }

  return $self->{'user'};
}

sub time_added {
  my $self = shift;
  $self->{'time_added'} = shift if ( @_ );
  return $self->{'time_added'};
}

sub kill_object_id {
  my $self = shift;
  $self->{'kill_object_id'} = shift if ( @_ );
  return $self->{'kill_object_id'};
}

sub message {
  my $self = shift;
  $self->{'message'} = shift if ( @_ );
  return $self->{'message'};
}

sub _clone_Comment {
  my ($self, $comment) = @_;
  my $newcomment = new Bio::EnsEMBL::KillList::Comment(
                   -user => Bio::EnsEMBL::KillList::User->_clone_User($comment->user),
                                                  );

  $newcomment->dbID            ( $comment->dbID );
  $newcomment->time_added      ( $comment->time_added );
  $newcomment->kill_object_id  ( $comment->kill_object_id );
  $newcomment->message         ( $comment->message );

  return $newcomment;
}
1;


