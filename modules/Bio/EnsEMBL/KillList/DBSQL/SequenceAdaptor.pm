# $Source: /tmp/ENSCOPY-ENSEMBL-KILLLIST/modules/Bio/EnsEMBL/KillList/DBSQL/SequenceAdaptor.pm,v $
# $Revision: 1.3 $

package Bio::EnsEMBL::KillList::DBSQL::SequenceAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::Sequence;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['sequence' , 's']);
}

sub _columns {
  my $self = shift;
  return ( 's.kill_object_id', 's.sequence');
}

sub fetch_by_dbID {
  my $self = shift;
  my $kill_obj_id = shift;
  my $constraint = "s.kill_object_id = '$kill_obj_id'";
  my ($sequence_obj) = @{ $self->generic_fetch($constraint) };
  return $sequence_obj;
}

sub fetch_by_sequence {
  my $self = shift;
  my $sequence = shift;
  my $constraint = "s.sequence = '$sequence'";
  my ($sequence_obj) = @{ $self->generic_fetch($constraint) };
  return $sequence_obj;
}

sub fetch_by_KillObject {
  my $self = shift;
  my $kill_object = shift;

  my $kill_obj_id = $kill_object->dbID;
  my $constraint = "s.kill_object_id = '$kill_obj_id'";
  my ($sequence_obj) = @{ $self->generic_fetch($constraint) };
  return $sequence_obj;
}

sub store {
  my ($self, $sequence_obj, $koi) = @_;

  if (!ref $sequence_obj || !$sequence_obj->isa('Bio::EnsEMBL::KillList::Sequence') ) {
    throw("Must store a Sequence sequence_object, not a $sequence_obj");
  }

  my $db = $self->db();

  if ($sequence_obj->is_stored($db)) {
    print STDERR "already stored this Sequence\n"; 
    return $sequence_obj->dbID();
  }

  my $sequence = $sequence_obj->sequence; 

  # make an sql statement
  my $original = $sequence_obj;
  my $sth;
  if (defined $koi) {
    $sth = $self->prepare(
           "INSERT INTO sequence (kill_object_id, sequence) ".
           "VALUES (?,?)");
    $sth->bind_param(1, $koi, SQL_INTEGER);
    $sth->bind_param(2, $sequence, SQL_VARCHAR);
  } else {
    $sth = $self->prepare(
           "INSERT INTO sequence ".
           "SET sequence = ?");
    $sth->bind_param(1, $sequence, SQL_VARCHAR);
  }
  $sth->execute();
  $sth->finish();

  my $sequence_obj_dbID = $sth->{'mysql_insertid'};

  # set the adaptor and dbID on the original passed in sequence_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($sequence_obj_dbID);
  print STDERR "Stored sequence object ".$original->dbID."\n";
  return $sequence_obj_dbID;
}


sub remove {
  my $self = shift;
  my $sequence_obj = shift;

  if (!ref($sequence_obj) || !$sequence_obj->isa('Bio::EnsEMBL::KillList::Sequence')) {
    throw("Bio::EnsEMBL::KillList::Sequence argument expected.");
  }

  if ( !$sequence_obj->is_stored($self->db()) ) {
    warning("Cannot remove sequence_obj " . $sequence_obj->dbID() . ". It is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing sequence_object ".$sequence_obj->dbID." from database...\n");

  # remove from sequence_
  my $sth = $self->prepare( "delete from sequence where kill_object_id = ? " );
  $sth->bind_param(1, $sequence_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the sequence_obj identifier and adaptor thereby flagging it as unstored
  $sequence_obj->dbID(undef);
  $sequence_obj->adaptor(undef);
  print STDERR "Removed sequence object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @out;
  my ( $kill_object_id, $sequence );
  $sth->bind_columns( \$kill_object_id, \$sequence );

  while($sth->fetch()) {
    #print STDERR "$kill_object_id, $sequence\n";
    push @out, Bio::EnsEMBL::KillList::Sequence->new(
              -dbID          => $kill_object_id,
              -adaptor       => $self,
              -sequence      => $sequence 
              );
  }
  return \@out;
}


1;

