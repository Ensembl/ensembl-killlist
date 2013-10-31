
package Bio::EnsEMBL::KillList::DBSQL::ReasonAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::Reason;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['reason' , 'r']);
}

sub _columns {
  my $self = shift;
  return ( 'r.reason_id', 'r.why', 'r.reason_description');
}

sub fetch_by_dbID {
  my $self = shift;
  my $reasonid = shift;
  my $constraint = "r.reason_id = '$reasonid'";
  my ($reason_obj) = @{ $self->generic_fetch($constraint) };
  return $reason_obj;
}

sub fetch_all_by_KillObject {
  my $self = shift;
  my $killobject = shift;
  my $sth = $self->prepare(
            "SELECT reason_id ".
            "FROM kill_object_reason kor, kill_object_status kos ".
            "WHERE kos.kill_object_id = kor.kill_object_id ".
            "AND kor.kill_object_id = ?");
  $sth->bind_param(1, $killobject->dbID, SQL_INTEGER);
  $sth->execute();
  my @reasonids;
  while (my $id = $sth->fetchrow) {
    push @reasonids, $id;
  }
  $sth->finish();

#  my @obj_ids = map {$_->[0]} @reasonids;
  my @obj_ids = @reasonids;
  my @reasons;
  foreach my $id (@obj_ids) {
    my $reason_object = $self->fetch_by_dbID($id); 
    push @reasons, $reason_object;
  }
  return \@reasons;
}

sub fetch_by_why {
  my $self = shift;
  my $keyword = shift;
  my $constraint = "r.why = '$keyword'";
  my ($reason_obj) = @{ $self->generic_fetch($constraint) };
  return $reason_obj;
}

sub fetch_all {
  my $self = shift;
  my @reasons = @{ $self->generic_fetch() };
  return \@reasons;
}

sub store {
  my ($self, $reason_obj) = @_;

  if (!ref $reason_obj || !$reason_obj->isa('Bio::EnsEMBL::KillList::Reason') ) {
    throw("Must store a Reason reason_object, not a $reason_obj");
  }

  my $db = $self->db();

  if ($reason_obj->is_stored($db)) {
    print STDERR "already stored this Reason"; 
    return $reason_obj->dbID();
  }

  my $reason_why = $reason_obj->why; 
  my $reason_desc = $reason_obj->reason_description;

  # make an sql statement
  my $original = $reason_obj;
  my $sth = $self->prepare(
            "INSERT INTO reason ".
            "SET why = ?, ".
            "reason_description = ?");

  $sth->bind_param(1, $reason_why, SQL_LONGVARCHAR);
  $sth->bind_param(2, $reason_desc, SQL_LONGVARCHAR);
  $sth->execute();
  $sth->finish();

  my $reason_obj_dbID = $sth->{'mysql_insertid'};

  # set the adaptor and dbID on the original passed in reason_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($reason_obj_dbID);
  print STDERR "Stored reason object ".$original->dbID."\n";
  return $reason_obj_dbID;
}


sub remove {
  my $self = shift;
  my $reason_obj = shift;

  if (!ref($reason_obj) || !$reason_obj->isa('Bio::EnsEMBL::KillList::Reason')) {
    throw("Bio::EnsEMBL::KillList::Reason argument expected.");
  }

  if ( !$reason_obj->is_stored($self->db()) ) {
    warning("Cannot remove reason_obj " . $reason_obj->dbID() . ". Is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing reason_object ".$reason_obj->dbID." from database...\n".
        "Entries in object_reason will not make sense\n"); 

  # remove from reason_
  my $sth = $self->prepare( "delete from reason where reason_id = ? " );
  $sth->bind_param(1, $reason_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the reason_obj identifier and adaptor thereby flagging it as unstored
  $reason_obj->dbID(undef);
  $reason_obj->adaptor(undef);
  print STDERR "Removed reason object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @out;
  my ( $reason_id, $reason_why, $reason_description );
  $sth->bind_columns( \$reason_id, \$reason_why, \$reason_description );

  while($sth->fetch()) {
    #print STDERR "$reason_id, $reason_why\n";
    push @out, Bio::EnsEMBL::KillList::Reason->new(
              -dbID               => $reason_id,
              -adaptor            => $self,
              -why                => $reason_why, 
              -reason_description => $reason_description,
              );
  }
  return \@out;
}


1;

