# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
package Bio::EnsEMBL::KillList::DBSQL::TeamAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::Team;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['team' , 't']);
}

sub _columns {
  my $self = shift;
  return ( 't.team_id', 't.team_name');
}

sub fetch_by_dbID {
  my $self = shift;
  my $teamid = shift;
  my $constraint = "t.team_id = '$teamid'";
  my ($team_obj) = @{ $self->generic_fetch($constraint) };
  return $team_obj;
}

sub fetch_by_team_name {
  my $self = shift;
  my $team_name = shift;
  my $constraint = "t.team_name = '$team_name'";
  my ($team_obj) = @{ $self->generic_fetch($constraint) };
  return $team_obj;
}

sub store {
  my ($self, $team_obj) = @_;

  if (!ref $team_obj || !$team_obj->isa('Bio::EnsEMBL::KillList::Team') ) {
    throw("Must store a Team team_object, not a $team_obj");
  }

  my $db = $self->db();

  if ($team_obj->is_stored($db)) {
    print STDERR "already stored this Team"; 
    return $team_obj->dbID();
  }

  my $team_name = $team_obj->team_name; 

  # make an sql statement
  my $original = $team_obj;
  my $sth = $self->prepare(
            "INSERT INTO team ".
            "SET team_name = ?");

  $sth->bind_param(1, $team_name, SQL_VARCHAR);
  $sth->execute();
  $sth->finish();

  my $team_obj_dbID = $sth->{'mysql_insertid'};

  # set the adaptor and dbID on the original passed in team_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($team_obj_dbID);
  print STDERR "Stored team object ".$original->dbID."\n";
  return $team_obj_dbID;
}


sub remove {
  my $self = shift;
  my $team_obj = shift;

  if (!ref($team_obj) || !$team_obj->isa('Bio::EnsEMBL::KillList::Team')) {
    throw("Bio::EnsEMBL::KillList::Team argument expected.");
  }

  if ( !$team_obj->is_stored($self->db()) ) {
    warning("Cannot remove team_obj " . $team_obj->dbID() . ". It is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing team_object ".$team_obj->dbID." from database...\n".
        "Entries in user will not make sense\n"); 

  # remove from team_
  my $sth = $self->prepare( "delete from team where team_id = ? " );
  $sth->bind_param(1, $team_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the team_obj identifier and adaptor thereby flagging it as unstored
  $team_obj->dbID(undef);
  $team_obj->adaptor(undef);
  print STDERR "Removed team object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @out;
  my ( $team_id, $team_name );
  $sth->bind_columns( \$team_id, \$team_name );

  while($sth->fetch()) {
    #print STDERR "$team_id, $team_name\n";
    push @out, Bio::EnsEMBL::KillList::Team->new(
              -dbID           => $team_id,
              -adaptor        => $self,
              -team_name      => $team_name 
              );
  }
  return \@out;
}


1;

