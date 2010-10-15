package Bio::EnsEMBL::KillList::DBSQL::KillObjectAdaptor; 

use strict;
use Bio::EnsEMBL::Storable;
use Data::Dumper;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::KillList::AnalysisLite;
use Bio::EnsEMBL::KillList::Reason;
use Bio::EnsEMBL::KillList::Species;
use Bio::EnsEMBL::KillList::KillObject; 
use Bio::EnsEMBL::KillList::Filter;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning );

use vars '@ISA';
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

# don't get anything from other tables 
sub _tables {
  my $self = shift;
  return ([ 'kill_object' , 'ko' ]
          );
}

sub _columns {
  my $self = shift;

  return ( 'ko.kill_object_id', 'ko.taxon_id', 'ko.mol_type',
           'ko.accession', 'ko.version', 'ko.external_db_id',
           'ko.description', 'ko.user_id',
         );
}

sub fetch_KillObjects_by_Filter {
  my ($self, $filter) = @_; #pass in like $kill_adaptor->fetch_KillObjects_by_Filter($filter);
  my (@analyses_allowed, @species_allowed, @reasons, @external_db_ids);

  my $sql_from = "SELECT ko.kill_object_id ".
                 "FROM kill_object ko, kill_object_status kos";
  my $sql_where = "WHERE ko.kill_object_id = kos.kill_object_id ".
                  "AND kos.is_current = 1";

  if ($filter->user) {
    print STDERR "Filter to user ".$filter->user->user_name."\n";
    $sql_where .= " AND ko.user_id = ".$filter->user->dbID." ";
  } else {
    print STDERR "> No user set for filter\n"; 
  }

  if ($filter->status) {
    print STDERR "Filter to status ".$filter->status."\n";
    $sql_where .= " AND kos.status = '".$filter->status."' ";
  } else {
    print STDERR "> No status set for filter. Fetch all that do not have status 'REMOVED'\n";
    $sql_where .= " AND kos.status != 'REMOVED' ";
  }

  if ($filter->source_species) {
    print STDERR "Filter to source_species ".$filter->source_species->name."\n";
    $sql_where .= " AND ko.taxon_id = ".$filter->source_species->dbID." "; 
  } else {
    print STDERR "> No source_species set for filter\n";
  }

  if (@{$filter->get_all_external_db_ids()}) {
    foreach my $external_id (@{$filter->get_all_external_db_ids()}) {
      print STDERR "Filter to external_db_id $external_id\n";
      push @external_db_ids, $external_id; 
    }
    $sql_where .= " AND ko.external_db_id in (".join(', ',@external_db_ids).") ";
  } else {
    print STDERR "> No external_db_id set for filter\n";
  }

  if ($filter->mol_type) {
    print STDERR "Filter to mol_type ".$filter->mol_type."\n";
    $sql_where .= " AND ko.mol_type = '".$filter->mol_type."' ";
  } else {
    print STDERR "> No mol_type set for filter\n";
  }

  if ($filter->timestamp) {
    print STDERR "Filter to date ".$filter->timestamp."\n";
    $sql_where .= "AND datediff(date('".$filter->timestamp."'), date(kos.time)) >= 0 ";
  } else {
    print STDERR "> No date set for filter\n";
  }

  my $sql = $sql_from." ".$sql_where; 
  print STDERR "SQL : \n".$sql."\n"; 

  my $sth = $self->prepare($sql);
  $sth->execute();

  my %kill_object_ids;
  while (my $id = $sth->fetchrow()) {
    $kill_object_ids{$id} = 1;
  }
  $sth->finish();
  print STDERR "\n\n(1) Have ".scalar(keys %kill_object_ids).", filtering further.\n";

  # Now filter down by analyses_allowed, species_allowed and reasons
  # Get all kill_object_ids in analysis bridging table
  my (@analysis_kill_object_ids, @species_kill_object_ids, @reason_kill_object_ids);
  if (@{$filter->get_all_Analyses_allowed()}) {
    foreach my $analysis (@{$filter->get_all_Analyses_allowed()}) {
      print STDERR "Filter to analysis_allowed ".$analysis->logic_name."\n";
      push @analyses_allowed, $analysis->dbID;
    }
    @analysis_kill_object_ids = @{_generic_bridge_fetch($self, 'kill_object_analysis', 'analysis_id', \@analyses_allowed)};
  } else {
    print STDERR "> No analysis set for filter\n";
  }

  # Get all kill_object_ids in species bridging table
  if (@{$filter->get_all_Species_allowed()} ) {
    foreach my $spp (@{$filter->get_all_Species_allowed()}) {
      print STDERR "Filter to species_allowed ".$spp->name."\n";
      push @species_allowed, $spp->taxon_id;
    }
    @species_kill_object_ids = @{_generic_bridge_fetch($self, 'species_allowed', 'taxon_id', \@species_allowed)};
  } else {
    print STDERR "> No species set for filter\n";
  }

  # Get all kill_object_ids in reason bridging table
  if (@{$filter->get_all_Reasons()} ) {
    foreach my $reason (@{$filter->get_all_Reasons()}) {
      print STDERR "Filter to reason ".$reason->why."\n";
      push @reasons,$reason->dbID;
    }
    @reason_kill_object_ids = @{_generic_bridge_fetch($self, 'kill_object_reason', 'reason_id', \@reasons)};
  } else {
    print STDERR "> No reasons set for filter\n";
  }


  #
  # now need to loop through the full list (%kill_object_ids)
  # and delete any entries that appear in any other the other
  # arrays (@species_kill_object_ids, @reason_kill_object_ids,
  # @analysis_kill_object_ids.)
  #
  my $num_deleted_analysis = 0;
  my $num_deleted_species  = 0;
  my $num_kept_reason   = 0;

  # delete entries in species_allowed
  foreach my $species_id (@species_kill_object_ids) {
    if (exists($kill_object_ids{$species_id})) {
      delete $kill_object_ids{$species_id};
      $num_deleted_species++;
    }
  }

  # delete entries in analysis_allowed
  foreach my $analysis_id (@analysis_kill_object_ids) {
    if (exists($kill_object_ids{$analysis_id})) {
      delete $kill_object_ids{$analysis_id};
      $num_deleted_analysis++;
    }
  }

  # now only get reasons specified
  foreach my $reason_id (@reason_kill_object_ids) {
    if (!exists($kill_object_ids{$reason_id})) {
      delete $kill_object_ids{$reason_id};
      $num_kept_reason++;
    }
  }

  # we now have the final list of dbIDs 
  my @list_to_fetch = keys %kill_object_ids; 
  print STDERR "(2) Removed from original (analysis) : $num_deleted_analysis\n";
  print STDERR "(3) Removed from original (species)  : $num_deleted_species\n";
  print STDERR "(4) Kept from original (reason)      : $num_kept_reason\n";
  print STDERR "(5) Now fetching ".scalar(@list_to_fetch)." objects\n";
  my $kill_objects = $self->fetch_all_by_dbID_list(\@list_to_fetch); 
  return $kill_objects;
}

sub _generic_bridge_fetch {
  my ($self, $table, $column, $ids) = @_;
  my @id_list;

  my $sql = "SELECT kill_object_id ".
                   "FROM $table ".
                   "WHERE $column in (".join(', ', @$ids).")";
  my $sth = $self->prepare($sql);
  $sth->execute();

  while (my $id = $sth->fetchrow()) {
    push @id_list, $id;
  }
  $sth->finish();
  return \@id_list;
}

sub _get_current_timestamp {
  my ($self) = @_;
  my $sth = $self->prepare("select current_timestamp()"); 
  $sth->execute();
  my $timestamp = $sth->fetchrow();
  $sth->finish();
  return $timestamp;
}

sub fetch_all_KillObjects {
  my $self = shift;
  my @kill_object_array;
  my $sth = $self->prepare(
            "SELECT kos.kill_object_id ".
            "FROM kill_object_status kos ".
            "WHERE kos.is_current = 1 ".
            "AND kos.status != 'REMOVED'");
  $sth->execute();
  while ( my $id = $sth->fetchrow()) {
    push @kill_object_array, $self->db()->get_KillObjectAdaptor->fetch_by_dbID($id);
  }
  return \@kill_object_array;
}

sub fetch_all_KillObjectIDs {
  my $self = shift;
  my %kill_object_ids; 
  print "testing\n" ; 
  my $sth = $self->prepare(
            "SELECT ko.kill_object_id ". 
            "FROM kill_object ko, kill_object_status kos ".
            "WHERE ko.kill_object_id = kos.kill_object_id ".
            "AND kos.status != 'REMOVED' ".
            "AND kos.is_current = 1"); 
  $sth->execute();
  while ( my $id = $sth->fetchrow()) {
    $kill_object_ids{$id} = 1;
  }
  return \%kill_object_ids;
}

sub fetch_all_before_date {
  my $self = shift;
  my $time = shift;

  #convert date string into something useful
  my $sth = $self->prepare("SELECT STR_TO_DATE('$time', GET_FORMAT(DATE,'EUR'));");
  $sth->execute();
  my $maxtime = $sth->fetchrow();

  #get all before this date
  $sth = $self->prepare(
                "SELECT kill_object_id ".
                "FROM kill_object_status ".
                "WHERE date(time) < '$maxtime' ".
                "AND status != 'REMOVED' ".
                "AND is_current = 1"); 
  $sth->execute();
  my @array = @{$sth->fetchall_arrayref()};
  my @kill_obj_ids = map {$_->[0]} @array;
  my $kill_objects = $self->fetch_all_by_dbID_list(\@kill_obj_ids);

  return $kill_objects;
}

sub old_fetch_all_older_than_days {
  my $self = shift;
  my $num_of_days = shift;

  my $constraint = "ko.time < (CURDATE() - INTERVAL $num_of_days DAY)";
  my @killobjects = @{ $self->generic_fetch($constraint) };
  return \@killobjects;
}

 
sub fetch_all_older_than_days {
  my $self = shift;
  my $num_of_days = shift;

  my $sth = $self->prepare(
                "SELECT kos.kill_object_id ".
                "FROM kill_object_status kos ".
                "WHERE kos.time < (CURDATE() - INTERVAL $num_of_days DAY)".
                "AND kos.status != 'REMOVED' ".
                "AND is_current = 1");
  $sth->execute();
  my @array = @{$sth->fetchall_arrayref()};
  my @kill_obj_ids = map {$_->[0]} @array;
  my $kill_objects = $self->fetch_all_by_dbID_list(\@kill_obj_ids);
  return $kill_objects;
}

sub fetch_all_by_userID  {
  my ($self, $userid) = @_;
  croak("user id argument is required") unless ($userid);

  my $sth = $self->prepare(
            "SELECT ko.kill_object_id
             FROM kill_object ko, kill_object_status kos
             WHERE ko.kill_object_id = kos.kill_object_id 
             AND user_id = ?
             AND kos.status != 'REMOVED'
             AND is_current = 1");  

  # $sth->bind_param(1, $userid, SQL_VARCHAR); 
  $sth->execute($userid); 

  my @array = @{$sth->fetchall_arrayref()};  
  my @kill_obj_ids = map {$_->[0]} @array;
  my $out = $self->fetch_all_by_dbID_list(\@kill_obj_ids);

  return $out;
}

sub fetch_by_commentID  {
  my ($self, $commentid) = @_;
  croak("comment id argument is required") unless ($commentid);

  my $sth = $self->prepare(
            "SELECT kill_object_id
             FROM comment 
             WHERE comment_id = ?");

  $sth->bind_param(1, $commentid, SQL_INTEGER);
  $sth->execute;

  my ($kill_object_id) = $sth->fetchrow();
  $sth->finish();

  return undef if (!defined $kill_object_id); 
  my $kill_object = $self->fetch_by_dbID($kill_object_id);
  return $kill_object;
}

sub fetch_all_by_dbID_list {
  my ($self,$id_list_ref) = @_;

  if(!defined($id_list_ref) || ref($id_list_ref) ne 'ARRAY') {
    croak("kill object id list reference argument is required");
  }

  return [] if(!@$id_list_ref);

  my @out;
  #construct a constraint like 't1.table1_id = 123'
  my @tabs = $self->_tables;
  my ($name, $syn) = @{$tabs[0]};

  # mysql is faster and we ensure that we do not exceed the max query size by
  # splitting large queries into smaller queries of 200 ids
  my $max_size = 200;
  my @id_list = @$id_list_ref;

  while(@id_list) {
    my @ids;
    if(@id_list > $max_size) {
      @ids = splice(@id_list, 0, $max_size);
    } else {
      @ids = splice(@id_list, 0);
    }

    my $id_str;
    if(@ids > 1)  {
      $id_str = " IN (" . join(',', @ids). ")";
    } else {
      $id_str = " = " . $ids[0];
    }

    my $constraint = "${syn}.${name}_id $id_str";
    push @out, @{$self->generic_fetch($constraint)};
  }
  return \@out;
}

sub fetch_by_dbID {
  my ($self, $objectid, $do_full_fetch) = @_;
  
  my $constraint = "ko.kill_object_id = '$objectid'";
  my ($kill_object) = @{$self->generic_fetch($constraint)};
  $kill_object->{'_current_status'} = $self->get_current_status($kill_object);

  if (defined $do_full_fetch) {
    my $reasons = $self->db()->get_ReasonAdaptor->fetch_all_by_KillObject($kill_object);
    foreach my $reason (@{$reasons}) {
      $kill_object->add_Reason($reason);
    }
    my $species = $self->db()->get_SpeciesAdaptor->fetch_all_by_KillObject($kill_object);
    foreach my $spp (@{$species}) {
      $kill_object->add_Species_allowed($spp);
    }
    my $analyses = $self->db()->get_AnalysisLiteAdaptor->fetch_all_by_KillObject($kill_object);
    foreach my $analysis (@{$analyses}) {
      $kill_object->add_Analysis_allowed($analysis);
    }
    my $comments = $self->db()->get_CommentAdaptor->fetch_all_by_KillObject($kill_object);
    foreach my $comment (@{$comments}) {
      $kill_object->add_Comment($comment);
    }
    my $sequence = $self->db()->get_SequenceAdaptor->fetch_by_KillObject($kill_object);
    $kill_object->sequence($sequence);
  }
  return $kill_object;
}

sub fetch_by_accession {
  my ($self, $accessionid, $do_full_fetch) = @_;
  my $killobj;

  my $sth = $self->prepare(
                  "SELECT ko.kill_object_id ".
                  "FROM kill_object ko, kill_object_status kos ".
                  "WHERE ko.kill_object_id = kos.kill_object_id ".
                  "AND ko.accession = ? ".
                  "AND kos.status != 'REMOVED' ".
                  "AND kos.is_current = 1");
  $sth->bind_param(1, $accessionid, SQL_VARCHAR);
  $sth->execute();

  # there should only be one is_current
  my $id = $sth->fetchrow();
  $sth->finish();
  
  return undef if (!$id);

  if (defined $do_full_fetch) {
    $killobj = $self->fetch_by_dbID($id, 1);
  } else {
    $killobj = $self->fetch_by_dbID($id);
  }
  return $killobj;
}

sub fetch_all_by_mol_type {
  my ($self, $moltype) = @_;
  
  my $sth = $self->prepare(
                  "SELECT ko.kill_object_id ".
                  "FROM kill_object ko, kill_object_status kos ".
                  "WHERE ko.kill_object_id = kos.kill_object_id ".
                  "AND ko.mol_type = ? ".
                  "AND kos.status != 'REMOVED' ".
                  "AND is_current = 1");
  $sth->bind_param(1, $moltype, SQL_VARCHAR);
  $sth->execute();

  my @array = @{$sth->fetchall_arrayref()};
  my @kill_obj_ids = map {$_->[0]} @array;
  my $kill_objects = $self->fetch_all_by_dbID_list(\@kill_obj_ids); 
  return $kill_objects; 
}

sub fetch_all_by_taxonID {
  my ($self, $taxonid) = @_;

  my $sth = $self->prepare(
                  "SELECT ko.kill_object_id ".
                  "FROM kill_object ko, kill_object_status kos ".
                  "WHERE ko.kill_object_id = kos.kill_object_id ".
                  "AND ko.taxon_id = ?".
                  "AND kos.status != 'REMOVED' ".
                  "AND is_current = 1");
  $sth->bind_param(1, $taxonid, SQL_VARCHAR);
  $sth->execute();

  my @array = @{$sth->fetchall_arrayref()};
  my @kill_obj_ids = map {$_->[0]} @array;
  my $kill_objects = $self->fetch_all_by_dbID_list(\@kill_obj_ids);
  return $kill_objects;
}
 
sub fetch_all_by_external_dbID {
  my ($self, $external_dbID) = @_; 

  my $sth = $self->prepare(
                  "SELECT ko.kill_object_id ".
                  "FROM kill_object ko, kill_object_status kos ".
                  "WHERE ko.kill_object_id = kos.kill_object_id ".
                  "AND ko.external_db_id = ? ".
                  "AND is_current = 1");
  $sth->bind_param(1, $external_dbID, SQL_VARCHAR);
  $sth->execute();

  my @array = @{$sth->fetchall_arrayref()};
  my @kill_obj_ids = map {$_->[0]} @array;
  my $kill_objects = $self->fetch_all_by_dbID_list(\@kill_obj_ids);
  return $kill_objects;
}

sub fetch_all_allowed_for_species {
  my ($self, $species_allowedID) = @_;
  my $sth = $self->prepare(
            "SELECT sa.kill_object_id ". 
            "FROM species_allowed sa, kill_object_status kos ".
            "WHERE sa.kill_object_id = kos.kill_object_id ".
            "AND sa.taxon_id = ? ".
            "AND kos.status != 'REMOVED' ".
            "AND kos.is_current = 1");

  $sth->bind_param(1, $species_allowedID, SQL_INTEGER);
  $sth->execute();
  my @ids;
  while (my $koi = $sth->fetchrow()) {
    push @ids, $koi;
  }
  $sth->finish();

  my @obj_ids = map {$_->[0]} @ids;
  return $self->fetch_all_by_dbID_list(\@obj_ids);
}

sub fetch_all_by_reasonID {
  my ($self, $reasonid) = @_;
 
  my $sth = $self->prepare(
            "SELECT kor.kill_object_id
             FROM kill_object_reason kor, kill_object_status kos 
             WHERE kor.kill_object_id = kos.kill_object_id 
             AND reason_id = ?
             AND kos.status != 'REMOVED'
             AND kos.is_current = 1");

  $sth->bind_param(1, $reasonid, SQL_VARCHAR);
  $sth->execute();
  my @ids;
  while (my $koi = $sth->fetchrow()) {
    push @ids, $koi;
  }
  $sth->finish();

 # my @obj_ids = map {$_->[0]} @ids;
  my @obj_ids = @ids;
  return $self->fetch_all_by_dbID_list(\@obj_ids);
}

sub fetch_by_Status {
  my ($self, $status, $start, $end) = @_;

  throw("Require status for fetch_by_Status")
         unless ($status);

  my $query = q{
      SELECT   ko.kill_object_id
      FROM     kill_object ko, kill_object_status kos,
      WHERE    ko.kill_object_id = kos.kill_object_id
      AND      kos.status = ?
      AND      kos.is_current = 1
      ORDER BY time dec
  };

  $query .= " LIMIT $start, $end" if ($start && $end);

  my $sth = $self->prepare($query);
  $sth->bind_param(1, $status, SQL_VARCHAR);
  my @ids;
  while (my $koi = $sth->fetchrow()) {
    push @ids, $koi;
  }
  $sth->finish();

 # my @obj_ids = map {$_->[0]} @ids;
  my @obj_ids = @ids;
  return $self->fetch_all_by_dbID_list(\@obj_ids);
}

sub set_status {
  my ($self, $kill_object, $status) = @_;
  my $kill_object_id;
  #my $status;

  if( ! defined ($kill_object_id = $kill_object->dbID)) {
    throw( "Kill_object has to be in database" );
  }
  if ($status ne 'CREATED' && $status ne 'UPDATED' && $status ne 'REINSTATED' && $status ne 'REMOVED') { 
    throw("Status '$status' not in CREATED, UPDATED, REINSTATED, REMOVED.");
  }

  eval {
    my $sth_insert = $self->prepare(
                              "INSERT into kill_object_status ".
                              "(kill_object_id, status, time, is_current) ".
                              "VALUES (?, ?, NOW(), 1) "
                              );

    $sth_insert->bind_param(1, $kill_object->dbID, SQL_INTEGER);
    $sth_insert->bind_param(2, $status, SQL_VARCHAR);
    $sth_insert->execute();
    $sth_insert->finish;
  };
  if ($@) {
    print( " $@ " );
    throw("Error while setting status to $status");
  } else {
    return $status;
  }
}

sub get_current_status {
  my ($self, $kill_object) = @_;

  my $sth = $self->prepare(
                  "SELECT status ".
                  "FROM kill_object_status ".
                  "WHERE is_current = 1 ".
                  "AND kill_object_id = ?");
  $sth->bind_param(1, $kill_object->dbID, SQL_INTEGER);
  $sth->execute();
  my $status = $sth->fetchrow();
  $sth->finish();
  $kill_object->{'_current_status'} = $status;

  return $kill_object->{'_current_status'};
}

sub get_timestamp {
  my ($self, $kill_object) = @_;

  my $sth = $self->prepare(
                  "SELECT date(time) ".
                  "FROM kill_object_status ".
                  "WHERE is_current = 1 ".
                  "AND kill_object_id = ?");
  $sth->bind_param(1, $kill_object->dbID, SQL_INTEGER);
  $sth->execute();
  my $time = $sth->fetchrow();
  $sth->finish();
  $kill_object->{'_timestamp'} = $time;

  return $kill_object->{'_timestamp'};
}

sub accession_stored {
  my ($self, $obj) = @_;
  my $accession_stored;

  # see whether anything of the same accession is current in the db
  my $sth = $self->prepare(
                  "SELECT ko.kill_object_id ".
                  "FROM kill_object ko, kill_object_status kos ".
                  "WHERE ko.kill_object_id = kos.kill_object_id ". 
                  "AND ko.accession = ? ".
                  "AND kos.is_current = 1");
  $sth->bind_param(1, $obj->accession, SQL_VARCHAR);
  $sth->execute();
  my $ko_id = $sth->fetchrow();
  $sth->finish();
  return $ko_id;
}

sub get_union {
  my ($current, $new) = @_;
  my $union = $new;
  my (%reasons, %species, %analyses, %comments);

  # fetch the object and compare it to the one passed in
  # decide whether the objects are identical
  if ($current->current_status eq 'REMOVED') {
    warn("This entry has been removed from the kill_list database ".
          "and should not be killed again.");
  }

  if (Bio::EnsEMBL::KillList::KillObject->_identical($current, $new)) {
    warn("The entry you are trying to store is identical to a current ".
         "entry in the database (see dbID ".$current->dbID.")"); 
  } else {
    warn("Getting union of entry to be stored, with existing entry dbID ".$current->dbID.".");
    #get the current settings
    #add new things to the union that occur in current and not in new
    #reasons:
    foreach my $reason1 (@{$current->get_all_Reasons()}) {
      my $found;
      foreach my $reason2 (@{$new->get_all_Reasons()}) {
        if ($reason1->dbID == $reason2->dbID) {
          $found = 1;
          last;
        }
      }
      if (!defined $found) {
        $union->add_Reason($reason1);     
      }
    }
    #species allowed:
    foreach my $species1 (@{$current->get_all_Species_allowed()}) {
      my $found;
      foreach my $species2 (@{$new->get_all_Species_allowed()}) {
        if ($species1->dbID == $species2->dbID) {
          $found = 1;
          last;
        }
      }
      if (!defined $found) {
        $union->add_Species_allowed($species1);
      }
    }
    #analyses:
    foreach my $analysis1 (@{$current->get_all_Analyses_allowed()}) {
      my $found;
      foreach my $analysis2 (@{$new->get_all_Analyses_allowed()}) {
        if ($analysis1->dbID == $analysis2->dbID) {
          $found = 1;
          last;
        }
      }
      if (!defined $found) {
        $union->add_Analysis_allowed($analysis1);
      }
    }
   #comments:
    foreach my $comment1 (@{$current->get_all_Comments()}) {
      my $found;
      foreach my $comment2 (@{$new->get_all_Comments()}) {
        if ($comment1->dbID == $comment2->dbID) {
          $found = 1;
          last;
        }
      } 
      if (!defined $found) {
        $union->add_Comment($comment1);
      }
    }
  } #else not identical
  return $union;
}

sub store {
  my ($self, $obj, $status, $force) = @_;
  my ($obj_to_store, $original); 
  my $db = $self->db();

  #print "OJB: ", $obj,"\nStatus: ",$status,"\n";


  # check that this is a KillObject
  if (!ref $obj || !$obj->isa('Bio::EnsEMBL::KillList::KillObject') ) {
    throw("Must store a KillObject object, not a $obj");
  }

  # see if there is an object with same db and same dbID in the database
  my $stored_dbID;
  if ($db->get_KillObjectAdaptor->accession_stored($obj)) {
    $stored_dbID = $db->get_KillObjectAdaptor->accession_stored($obj);
    print STDERR "already stored\n"; 
    #return $obj->dbID();
  }

  #see if there is an identical object in the database
  #also decide on a status
  if ($stored_dbID) {
    $status = "UPDATED";
    print STDERR "Entry with same accession has already been stored under another dbID: ".$stored_dbID."\n";
    my $current = $self->fetch_by_dbID($stored_dbID,1);
    if (!defined $force) {
      throw ("Object will only be stored if you use the -force option\n");
    } elsif (defined $force && $current->current_status ne 'REMOVED') {
      #store union
      print STDOUT "THIS IS THE CURRENT OBJECT\n";
      #print STDOUT Dumper($current); 
      print STDOUT "THIS IS THE NEW OBJECT\n";
      #print STDOUT Dumper($obj);
      $obj_to_store = get_union($current,$obj);
    } elsif (defined $force && $current->current_status eq 'REMOVED') {
      $status = "REINSTATED";
      warn("Object was previously removed from kill_list database. You are ".
           "now adding it back to the kill_list");
      $obj_to_store = $obj;
    }

    #set the current to be not_current as we will be saving a new entry in its place 
    my $sth = $self->prepare(
              "UPDATE kill_object_status kos, kill_object ko ".
              "SET kos.is_current = 0 ".
              "WHERE ko.kill_object_id = kos.kill_object_id ".
              "AND ko.accession = ?");
    $sth->bind_param(1, $current->accession, SQL_VARCHAR);
    $sth->execute();
    $sth->finish();
  } else {
    #store new
    $obj_to_store = $obj;
    # we may have passed in a status 
    # if so, we don't want to over-write it
    if (!defined $status || $status == 0) {
      $status = "CREATED";
    }
  } 
  print STDOUT "THIS IS THE UNION\n" if ($stored_dbID);
  #print STDOUT Dumper($obj_to_store);


  # these four should already be set
  my $user   = $obj_to_store->user;
  throw("Object to be stored needs a user_id.") if (!defined($user));
  my $mol_type  = $obj_to_store->mol_type;
  throw("Object to be stored needs a mol_type.") if (!defined($mol_type));
  my $accession = $obj_to_store->accession;
  throw("Object to be stored needs an accession.") if (!defined($accession));
  my $reasons = $obj_to_store->get_all_Reasons();
  throw("Object to be stored needs at least one reason.") if (!(@{$reasons}));
 
  # these ones may not be set. If not set, give them defaults
  my $taxon_id        = $obj_to_store->taxon->taxon_id;
  my $version         = $obj_to_store->version || $accession;
  my $external_db_id  = $obj_to_store->external_db_id || 0;
  my $description     = $obj_to_store->description || " ";

  # default to is_current = 1 
  my $is_current = 1;

  # make an sql statement
  $original = $obj_to_store;
  my $sth = $self->prepare(
            "INSERT INTO kill_object ".
            "SET taxon_id = ? , ".
            "mol_type = ? , ".
            "accession = ? , ".
            "version = ? , ".
            "external_db_id = ? , ".
            "description = ? , ".
            "user_id = ?"); 

  $sth->bind_param(1, $taxon_id, SQL_INTEGER);
  $sth->bind_param(2, $mol_type, SQL_VARCHAR);
  $sth->bind_param(3, $accession, SQL_VARCHAR);
  $sth->bind_param(4, $version, SQL_VARCHAR);
  $sth->bind_param(5, $external_db_id, SQL_INTEGER);
  $sth->bind_param(6, $description, SQL_LONGVARCHAR);
  $sth->bind_param(7, $user->dbID, SQL_INTEGER);
  $sth->execute();
  $sth->finish();

  my $kill_obj_dbID = $sth->{'mysql_insertid'};
  print STDERR "kill_object_id = $kill_obj_dbID\n";
  # add the reasons
  foreach my $reason (@{$reasons}) {
    $sth = $self->prepare("INSERT INTO kill_object_reason".
           "(kill_object_id, reason_id) ".
           "VALUES (?, ?)");
    $sth->bind_param(1, $kill_obj_dbID, SQL_INTEGER);
    $sth->bind_param(2, $reason->dbID, SQL_INTEGER);
    $sth->execute();
    $sth->finish();
  }

  # add analyses
  my %tmp_analyses;
  # ensure no duplicates
  foreach my $analysis (@{$obj_to_store->get_all_Analyses_allowed()}) { 
    $tmp_analyses{$analysis} = $analysis;
  }
  foreach my $analysis (keys %tmp_analyses) {
    print STDERR "Adding analysis $analysis\n";
    $sth = $self->prepare(
           "INSERT INTO kill_object_analysis ".
           "(kill_object_id, analysis_id) ".
           "VALUES (?, ?)");
    $sth->bind_param(1, $kill_obj_dbID, SQL_INTEGER);
    $sth->bind_param(2, $tmp_analyses{$analysis}->dbID, SQL_INTEGER);
    $sth->execute();
    $sth->finish();
  }

  # add species allowed
  my %tmp_species;
  # ensure no duplicates
  foreach my $species (@{$obj_to_store->get_all_Species_allowed()}) {
    $tmp_species{$species} = $species;
  }
  foreach my $species (keys %tmp_species) {
    $sth = $self->prepare(
           "INSERT INTO species_allowed ".
           "(taxon_id, kill_object_id) ".
           "VALUES (?, ?)");
    $sth->bind_param(1, $tmp_species{$species}->taxon_id, SQL_INTEGER);
    $sth->bind_param(2, $kill_obj_dbID, SQL_INTEGER);
    $sth->execute();
    $sth->finish(); 
  }

  # add sequence
  $self->db->get_SequenceAdaptor->store($obj_to_store->sequence, $kill_obj_dbID);

  # add comments
  my $comments = $obj_to_store->get_all_Comments();
  foreach my $comment (@{$comments}) {
    $comment->adaptor(undef);
    $comment->dbID(undef);
    $self->db->get_CommentAdaptor->store($comment, $kill_obj_dbID);
  }

  # set the adaptor and dbID on the original passed in obj_to_store not the
  # transferred copy
  $original->adaptor($self);
  $original->dbID($kill_obj_dbID);
#  print "OBJ to store: ", $obj_to_store,"\nStatus: ",$status,"\n";

  $self->set_status( $obj_to_store, $status);
  print STDERR "Entry ".$original->accession." with dbID ".$original->dbID." has been stored with status $status\n";
  return $kill_obj_dbID;
}


sub remove {
  my $self = shift;
  my $obj = shift;

  if (!ref($obj) || !$obj->isa('Bio::EnsEMBL::KillList::KillObject')) {
    throw("Bio::EnsEMBL::KillList::KillObject argument expected.");
  }

  if ( !$self->accession_stored($obj) ) {
    warning("Cannot remove obj with dbID [" . $obj->dbID() . "] as it is not stored in " .
            "this database.");
    return;
  }

  # change all other entries of this accession to be not current
  my $sth = $self->prepare(
                   "UPDATE kill_object_status kos, kill_object ko ".
                   "SET kos.is_current = 0 ".
                   "WHERE ko.kill_object_id = kos.kill_object_id ".
                   "AND ko.accession = ?");
  $sth->bind_param(1, $obj->accession, SQL_VARCHAR);
  $sth->execute();
  $sth->finish();

  # unset the obj identifier and adaptor thereby flagging it as unstored
  $obj->dbID(undef);
  $obj->adaptor(undef);
 
  # when removingkill-objects their sequences are not re-stored
  #$obj->sequence->dbID(undef);
  #$obj->sequence->adaptor(undef);

  # now store the object with a 'removed' status
  my $new_dbid = $self->store($obj, "REMOVED");

  print STDERR "Remove successful.\n";
  return $new_dbid;
}

sub update {
  my ($self, $kill_object) = @_;
 
  if ( !defined $kill_object || !ref($kill_object) ) {
    throw("Must update a kill_object, not a $kill_object");
  }

  #compare against current version
  my $sth = $self->prepare(
                   "SELECT ko.kill_object_id ".
                   "FROM kill_object_status kos, kill_object ko ".
                   "WHERE ko.kill_object_id = kos.kill_object_id ".
                   "AND kos.is_current = 1 ".
                   "AND ko.accession = ?");
  $sth->bind_param(1, $kill_object->accession, SQL_VARCHAR);
  $sth->execute();
  my ($existing_dbID) = $sth->fetchrow();
  my $current = $self->fetch_by_dbID($existing_dbID,1); 
  $sth->finish();
  my $identical = Bio::EnsEMBL::KillList::KillObject->_identical($current, $kill_object);

  my $cloned_KillObject = Bio::EnsEMBL::KillList::KillObject->_clone_KillObject($kill_object);
  # change all other entries of this accession to be not current
  $sth = $self->prepare(
                   "UPDATE kill_object_status kos, kill_object ko ".
                   "SET kos.is_current = 0 ".
                   "WHERE ko.kill_object_id = kos.kill_object_id ".
                   "AND ko.accession = ?");
  $sth->bind_param(1, $kill_object->accession, SQL_VARCHAR);
  $sth->execute();
  $sth->finish();
  # unset the obj identifier and adaptor thereby flagging it as unstored
  $kill_object->dbID(undef);
  $kill_object->adaptor(undef);

  # now store the object with a 'removed' status
  my $new_dbid = $self->store($kill_object, "UPDATED");

  return $new_dbid;
}

sub was_removed {
  my ($self, $kill_object) = @_;
  my $was_removed;

  my $sth = $self->prepare(
            "SELECT ko.kill_object_id, kos.status ".
            "FROM kill_object ko, kill_object_status kos ".
            "WHERE ko.kill_object_id = kos.kill_object_id ".
            "AND  kos.is_current = 1 ".
            "AND ko.accession = ?"); 
  $sth->bind_param(1, $kill_object->accession, SQL_VARCHAR);
  $sth->execute();
  my ($id, $status ) = $sth->fetchrow_array(); 
  $sth->finish();
  if (defined($id) && $status eq 'REMOVED' ) {
    $was_removed = 1;
  }
  return $was_removed;
}

=head2 is_killed

  Check whether an accession is killed in the db

=cut

sub is_killed {
  my ($self, $accession) = @_ ;
  my $entry;
  $accession =~ s/\.\d+//;

  # Look in the db
  my $sth = $self->prepare(
            "SELECT ko.kill_object_id  ".
            "FROM kill_object ko, kill_object_status kos ".
            "WHERE ko.kill_object_id = kos.kill_object_id ".
            "AND  kos.is_current = 1 ".
            "AND  kos.status != 'REMOVED' ".
            "AND ko.accession = ?");
  $sth->bind_param(1, $accession, SQL_VARCHAR);
  $sth->execute();
  my ($id) = $sth->fetchrow();
  $sth->finish();

  # Check if found
  if (defined($id) ) {
    $entry =  $self->fetch_by_dbID($id, 1);
  }

  return $entry;
}


sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my $sa = $self->db->get_SpeciesAdaptor();

  my @out;
  my (  $kill_object_id, $taxon_id, $mol_type,
       $accession, $version, $external_db_id,
       $description, $user_id,
     );

  $sth->bind_columns( \$kill_object_id, \$taxon_id, \$mol_type,
       \$accession, \$version, \$external_db_id,
       \$description, \$user_id, 
        );

  while($sth->fetch()) { 

   # print STDERR "$kill_object_id, $taxon_id, $mol_type, $accession, $version, $external_db_id, $description, $user_id\n";  


    push @out, Bio::EnsEMBL::KillList::KillObject->new(
              -dbID           => $kill_object_id,
              -adaptor        => $self,
              -taxon_id       => $taxon_id, 
              -mol_type       => $mol_type,
              -accession      => $accession,
              -version        => $version,
              -external_db_id => $external_db_id,
              -description    => $description,
              -user_id        => $user_id, 
              -kill_list_dbadaptor => $self->db, 
              );
  }
  foreach my $o (@out) {
    $o->timestamp($self->get_timestamp($o));
  }
  return \@out;
}

1;


