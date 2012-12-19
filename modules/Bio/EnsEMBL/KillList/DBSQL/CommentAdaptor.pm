# $Source: /tmp/ENSCOPY-ENSEMBL-KILLLIST/modules/Bio/EnsEMBL/KillList/DBSQL/CommentAdaptor.pm,v $
# $Revision: 1.2 $

package Bio::EnsEMBL::KillList::DBSQL::CommentAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::Comment;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['comment' , 'c']);
}

sub _columns {
  my $self = shift;
  return ( 'c.comment_id', 'c.user_id', 'c.time_added', 'c.kill_object_id', 'c.message');
}

sub fetch_all_before_date {
  my $self = shift;
  my $time = shift;

  #convert date string into something useful
  my $sth = $self->prepare("SELECT STR_TO_DATE('$time', GET_FORMAT(DATE,'EUR'));");
  $sth->execute();
  my $maxtime = $sth->fetchrow();

  #get all before this date 
  my $constraint = "date(c.time_added) < '$maxtime'";
  my @comments = @{ $self->generic_fetch($constraint) };
  return \@comments;
}

sub fetch_all_older_than_days {
  my $self = shift;
  my $num_of_days = shift;

  my $constraint = "c.time_added < (CURDATE() - INTERVAL $num_of_days DAY)";
  my @comments = @{ $self->generic_fetch($constraint) };
  return \@comments;
}

sub fetch_all_by_KillObject {
  my $self = shift;
  my $killobject = shift;
  my $killobject_id = $killobject->dbID;
  my $constraint = "c.kill_object_id = '$killobject_id'";
  my @comments = @{ $self->generic_fetch($constraint) };
  return \@comments;
}  

sub fetch_all_by_userID {
  my $self = shift;
  my $userid = shift;
  my $constraint = "c.user_id = '$userid'";
  my @comments = @{ $self->generic_fetch($constraint) };
  return \@comments;
}

sub fetch_by_dbID {
  my $self = shift;
  my $messageid = shift;
  my $constraint = "c.comment_id = '$messageid'";
  my ($comment) = @{ $self->generic_fetch($constraint) };
  return $comment;
}

sub store {
  my ($self, $comment_obj, $killobj_id) = @_;

  if (!ref $comment_obj || !$comment_obj->isa('Bio::EnsEMBL::KillList::Comment') ) {
    throw("Must store a Comment comment_object, not a $comment_obj");
  }

  my $db = $self->db();

  if ($comment_obj->is_stored($db)) {
    print STDERR "already stored this Comment\n"; 
    return $comment_obj->dbID();
  }

  if (!defined($killobj_id)) {
    $killobj_id = $comment_obj->kill_object_id;
  }

  my $user_id    = $comment_obj->user->dbID;
  my $message    = $comment_obj->message;

  # make an sql statement
  my $original = $comment_obj;
  my $sth = $self->prepare(
            "INSERT INTO comment ".
            "SET user_id = ?, ".
            "kill_object_id = ?, ".
            "message = ?, ".
            "time_added = now()");

  $sth->bind_param(1, $user_id, SQL_INTEGER);
  $sth->bind_param(2, $killobj_id, SQL_INTEGER);
  $sth->bind_param(3, $message, SQL_LONGVARCHAR);
  $sth->execute();
  $sth->finish();

  my $comment_obj_dbID = $sth->{'mysql_insertid'};

  $sth = $self->prepare("SELECT NOW()");
  $sth->execute();
  my $time = ($sth->fetchrow_arrayref())->[0];

  # set the adaptor and dbID on the original passed in comment_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($comment_obj_dbID);
  $original->time_added($time);
  #print STDERR "Stored comment object ".$original->dbID." for user ".$original->user->dbID."\n";
  return $comment_obj_dbID;
}


sub remove {
  my $self = shift;
  my $comment_obj = shift;

  warn("It is recommended that you do not remove comments as these provide a ".
       "record of what happened to the killobj");

  if (!ref($comment_obj) || !$comment_obj->isa('Bio::EnsEMBL::KillList::Comment')) {
    throw("Bio::EnsEMBL::KillList::Comment argument expected.");
  }

  if ( !$comment_obj->is_stored($self->db()) ) {
    warning("Cannot remove comment_obj with dbID [" . $comment_obj->dbID() . "]. It is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing comment_object ".$comment_obj->dbID." from database...\n");

  # remove from comment_
  my $sth = $self->prepare( "delete from comment where comment_id = ? " );
  $sth->bind_param(1, $comment_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the comment_obj identifier and adaptor thereby flagging it as unstored
  $comment_obj->dbID(undef);
  $comment_obj->adaptor(undef);
  print STDERR "Removed comment object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my $ua = $self->db->get_UserAdaptor();

  my @out;
  my ( $comment_id, $user_id, $time_added, $kill_object_id, $message );
  $sth->bind_columns( \$comment_id, \$user_id, \$time_added, \$kill_object_id, \$message );

  while($sth->fetch()) {
    #print STDERR "$comment_id, $user_id, $time_added, $kill_object_id, $message \n";
    my $user = $ua->fetch_by_dbID($user_id);
    push @out, Bio::EnsEMBL::KillList::Comment->new(
              -dbID           => $comment_id,
              -adaptor        => $self,
              -user           => $user,
              -time_added     => $time_added,
              -kill_object_id => $kill_object_id,
              -message        => $message
              );
  }
  return \@out;
}


1;

