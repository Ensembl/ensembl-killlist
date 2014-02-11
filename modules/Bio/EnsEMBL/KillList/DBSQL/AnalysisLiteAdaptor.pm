# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::KillList::DBSQL::AnalysisLiteAdaptor; 

use strict;
use warnings;
use Bio::EnsEMBL::KillList::AnalysisLite;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


sub _tables {
  my $self = shift;
  return (['analysis' , 'a']);
}

sub _columns {
  my $self = shift;
  return ( 'a.analysis_id', 'a.logic_name', 'a.description', 'a.program' );
}

sub fetch_all {
  my $self = shift;
  my ( $analysis, $dbID );
  my $rowHashRef;

  $self->{_cache} = {};
  $self->{_logic_name_cache} = {};

  my $sth = $self->prepare( q {
    SELECT analysis_id, logic_name,
           program, 
           description,
    FROM   analysis a, kill_object_analysis koa, kill_object_status kos
    WHERE analysis.analysis_id = kill_object_analysis.analysis_id
    AND   koa.kill_object_id = kos.kill_object_id
    AND   kos.is_current = 1
    AND   kos.status in ('CREATED', 'REINSTATED')
     } );
  $sth->execute;

  while( $rowHashRef = $sth->fetchrow_hashref ) {
    my $analysis = $self->_objFromHashref( $rowHashRef  );

    $self->{_cache}->{$analysis->dbID}                    = $analysis;
    $self->{_logic_name_cache}->{lc($analysis->logic_name())} = $analysis;
  }

  my @ana = values %{$self->{_cache}};

  return \@ana;
}

sub fetch_by_dbID {
  my $self = shift;
  my $analysisid = shift;
  my $constraint = "a.analysis_id = '$analysisid'";
  my ($analysis_obj) = @{ $self->generic_fetch($constraint) };
  return $analysis_obj;
}

sub fetch_by_logic_name {
  my $self = shift;
  my $logicname = shift;
  my $constraint = "a.logic_name = '$logicname'";
  my ($analysis_obj) = @{ $self->generic_fetch($constraint) };
  return $analysis_obj;
}

sub fetch_all_by_program {
  my $self = shift;
  my $program = shift;
  my $constraint = "a.program = '$program'";
  my @analysis_objs = @{ $self->generic_fetch($constraint) };
  return \@analysis_objs;
}

sub fetch_all_by_KillObject {
  my $self = shift;
  my $killobject = shift;
  my $sth = $self->prepare(
            "SELECT analysis_id ".
            "FROM kill_object_analysis koa, kill_object_status kos ".
            "WHERE koa.kill_object_id = kos.kill_object_id ".
            "AND koa.kill_object_id = ?");
  $sth->bind_param(1, $killobject->dbID, SQL_INTEGER);
  $sth->execute();
  my @analysisids;
  while (my $id = $sth->fetchrow) {
    push @analysisids, $id;
  }
  $sth->finish();

#  my @obj_ids = map {$_->[0]} @analysisids;
  my @obj_ids = @analysisids;
  my @analyses;
  foreach my $id (@obj_ids) {
    my $analysis_object = $self->fetch_by_dbID($id);
    push @analyses, $analysis_object;
  }
  return \@analyses;
}

sub store {
  my ($self, $analysislite_obj) = @_;
 
  warn("It should not be necessary to store an analysis as there is ".
       "already quite a long list of them...");

  if (!ref $analysislite_obj || !$analysislite_obj->isa('Bio::EnsEMBL::KillList::AnalysisLite') ) {
    throw("Must store an AnalysisLite object, not a $analysislite_obj");
  }

  my $db = $self->db();

  if ($analysislite_obj->is_stored($db)) {
    print STDERR "already stored this AnalysisLite\n"; 
    return $analysislite_obj->dbID();
  }

  my $analysis_name = $analysislite_obj->logic_name;
  my $description   = $analysislite_obj->description; 
  my $program       = $analysislite_obj->program;

  # make an sql statement
  my $original = $analysislite_obj;
  my $sth = $self->prepare(
            "INSERT INTO analysis ".
            "SET logic_name = ?, ".
            "description = ?, ".
            "program = ?");

  $sth->bind_param(1, $analysis_name, SQL_VARCHAR);
  $sth->bind_param(2, $description, SQL_LONGVARCHAR);
  $sth->bind_param(3, $program, SQL_VARCHAR);
  $sth->execute();
  $sth->finish();

  my $analysislite_obj_dbID = $sth->{'mysql_insertid'};

  # set the adaptor and dbID on the original passed in analysislite_obj not the
  # transfered copy
  $original->adaptor($self);
  $original->dbID($analysislite_obj_dbID);
  print STDERR "Stored analysislite object ".$original->dbID."\n";
  return $analysislite_obj_dbID;
}


sub remove {
  my $self = shift;
  my $analysislite_obj = shift;

  warn("You should not need to remove an analysis.");

  if (!ref($analysislite_obj) || !$analysislite_obj->isa('Bio::EnsEMBL::KillList::AnalysisLite')) {
    throw("Bio::EnsEMBL::KillList::AnalysisLite argument expected.");
  }

  if ( !$analysislite_obj->is_stored($self->db()) ) {
    warning("Cannot remove analysislite_obj " . $analysislite_obj->dbID() . ". Is not stored in " .
            "this database.");
    return;
  }

  warn ("Removing analysislite_object ".$analysislite_obj->dbID." from database...\n".
        "Entries in tables eg. object_analysis and object_analysis_status will not make sense");

  # remove from analysislite_
  my $sth = $self->prepare( "delete from analysis where analysis_id = ? " );
  $sth->bind_param(1, $analysislite_obj->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  # unset the analysislite_obj identifier and adaptor thereby flagging it as unstored
  $analysislite_obj->dbID(undef);
  $analysislite_obj->adaptor(undef);
  print STDERR "Removed analysislite object.\n";
  return;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  my @out;
  my ( $analysis_id, $logic_name, $description, $program );
  $sth->bind_columns( \$analysis_id, \$logic_name, \$description, \$program );
  while($sth->fetch()) {
    #print STDERR "$analysis_id, $logic_name, $description, $program\n";
    push @out, Bio::EnsEMBL::KillList::AnalysisLite->new(
              -dbID         => $analysis_id,
              -adaptor      => $self,
              -logic_name   => $logic_name,
              -description  => $description,
              -program      => $program
              );
  }
  return \@out;
}


1;

