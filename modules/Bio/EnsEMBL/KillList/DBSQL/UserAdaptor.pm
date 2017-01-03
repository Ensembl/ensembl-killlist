# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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
package Bio::EnsEMBL::KillList::DBSQL::UserAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::User;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['user' , 'u'],
          );
}

sub _columns {
  my $self = shift;
  return ( 'u.user_id', 'u.user_name', 'u.full_name', 'u.email', 'u.team_id'); 
}

sub get_dbID_from_name {
  my ($self, $user_name) = @_;
  my ($user_id, $sth);

  #we don't know what format the name will be in
  if ($user_name =~ m/\S+/) {
    $sth = $self->prepare(
           "SELECT user_id ".
           "FROM user ".
           "WHERE user_name = ?");
  } elsif ($user_name =~ /\w+\s+\w+/) {
    $sth = $self->prepare(
           "SELECT user_id ".
           "FROM user ".
           "WHERE full_name = ?");
  } else {
    throw("User_name is not in a recognizable format"); 
  }
  $sth->execute($user_name);
  $user_id = $sth->fetchrow();
  $sth->finish;
  return $user_id;
}

sub fetch_by_dbID {
  my $self = shift;
  my $userid = shift;
  my $constraint = "u.user_id = '$userid'";
  my ($user) = @{ $self->generic_fetch($constraint) };
  return $user;
}

sub fetch_by_user_name {
  my $self = shift;
  my $username = shift;
  my $constraint = "u.user_name = '$username'";
  my ($user) = @{ $self->generic_fetch($constraint) };
  return $user;
}

sub fetch_all_by_team {
  my $self = shift;
  my $team = shift;
  my $team_id = $team->dbID;
  print STDERR "\n\nteam id is $team_id\n";
  my $constraint = "u.team_id = '$team_id'";
  my @users = @{ $self->generic_fetch($constraint) };
  return \@users;
}

sub fetch_all {
  my $self = shift;
  my @users = @{ $self->generic_fetch() };
  return \@users;
}

sub store {
  my ($self, $user_obj) = @_;

  if (!ref $user_obj || !$user_obj->isa('Bio::EnsEMBL::KillList::User') ) {
    throw("Must store a User user_object, not a $user_obj");
  }

  my $db = $self->db();

  if ($user_obj->is_stored($db)) {
    print STDERR "already stored this User"; 
    return $user_obj->dbID();
  }

  my $user_name = $user_obj->user_name;
  my $full_name = $user_obj->full_name; 
  my $email     = $user_obj->email;
  my $team_id   = $user_obj->team->dbID;

  # make an sql statement
  my $original = $user_obj;
  my $sth = $self->prepare(
            "INSERT INTO user ".
            "SET user_name = ?, ".
            "full_name = ?, ".
            "email = ?, ".
            "team_id = ?");

  $sth->bind_param(1, $user_name, SQL_VARCHAR);
  $sth->bind_param(2, $full_name, SQL_LONGVARCHAR);
  $sth->bind_param(3, $email, SQL_VARCHAR);
  $sth->bind_param(4, $team_id, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  my $user_obj_dbID = $sth->{'mysql_insertid'};

  # set the adaptor and dbID on the original passed in user_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($user_obj_dbID);
  print STDERR "Stored user object ".$original->dbID."\n";
  return $user_obj_dbID;
}


sub remove {
  my $self = shift;
  my $user_obj = shift;

  if (!ref($user_obj) || !$user_obj->isa('Bio::EnsEMBL::KillList::User')) {
    throw("Bio::EnsEMBL::KillList::User argument expected.");
  }

  if ( !$user_obj->is_stored($self->db()) ) {
    warning("Cannot remove user_obj " . $user_obj->dbID() . ". Is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing user_object ".$user_obj->dbID." from database...\n".
        "Entries in tables eg. comment will not make sense");

  # remove from user_
  my $sth = $self->prepare( "delete from user where user_id = ? " );
  $sth->bind_param(1, $user_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the user_obj identifier and adaptor thereby flagging it as unstored
  $user_obj->dbID(undef);
  $user_obj->adaptor(undef);
  print STDERR "Removed user object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @out;
  my ( $user_id, $user_name, $full_name, $email, $team_id); 
  $sth->bind_columns( \$user_id, \$user_name, \$full_name, \$email, \$team_id ); 

  my $ta = $self->db->get_TeamAdaptor();

  while($sth->fetch()) {
    #print STDERR "$user_id, $user_name, $full_name, $email, $team_id\n";
    my $team = $ta->fetch_by_dbID($team_id);
    push @out, Bio::EnsEMBL::KillList::User->new(
              -dbID      => $user_id,
              -adaptor   => $self,
              -user_name => $user_name,
              -full_name => $full_name,
              -email     => $email,
              -team      => $team,
              );
  }
  return \@out;
}


1;

