package Bio::EnsEMBL::KillList::HiveKillList;

use strict;
use warnings;
use feature 'say';

use Bio::EnsEMBL::Analysis::Tools::Utilities;
use Bio::EnsEMBL::KillList::AnalysisLite;
use Bio::EnsEMBL::KillList::Comment;
use Bio::EnsEMBL::KillList::Filter;
use Bio::EnsEMBL::KillList::KillObject;
use Bio::EnsEMBL::KillList::Reason;
use Bio::EnsEMBL::KillList::Sequence;
use Bio::EnsEMBL::KillList::Species;
use Bio::EnsEMBL::KillList::Team;
use Bio::EnsEMBL::KillList::User;
use Bio::EnsEMBL::KillList::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use vars qw (@ISA);
@ISA = qw();


=head2

  Arg[1]      :  
  Example     :
  Description :
  Return type : 
  Exceptions  :
  Caller      :
  Status      :

=cut
sub new {
  my($class,@args) = @_; 

  my $self = bless {},$class;

  my ($type, $gb_ref_db, $kill_list_db, $filter_params) =
          rearrange([qw(TYPE
                        GB_REF_DB
                        KILL_LIST_DB
                        FILTER_PARAMS
                        )],@args);

  if (!defined($type)) {throw " ERROR: need to set -type\n";}
  $self->type          ( $type );
  $self->GB_REF_DB     ( $gb_ref_db ) if ( defined $gb_ref_db );
  $self->KILL_LIST_DB  ( $kill_list_db ) if ( defined $kill_list_db );
  $self->FILTER_PARAMS ( $filter_params ) if ( defined $filter_params );

  return $self; # success - we hope!
}

=head2

  Arg[1]      :
  Example     :
  Description :
  Return type :
  Exceptions  :
  Caller      :
  Status      :

=cut
sub type {
  my $self = shift;
  $self->{'type'} = shift if ( @_ );
  return $self->{'type'};
}

=head2

  Arg[1]      :
  Example     :
  Description :
  Return type :
  Exceptions  :
  Caller      :
  Status      :

=cut
sub GB_REF_DB {
  my ($self, $ref_db) = @_; 

  if ( !$self->{'GB_REF_DB'} ) {
    $self->{'GB_REF_DB'} = {};
  } 

  if ( $ref_db ) {
    $self->{'GB_REF_DB'} = $ref_db;
  }
  return $self->{'GB_REF_DB'};
}

=head2

  Arg[1]      :
  Example     :
  Description :
  Return type :
  Exceptions  :
  Caller      :
  Status      :

=cut
sub KILL_LIST_DB {
  my ($self, $db_params) = @_;

  if ( !$self->{'KILL_LIST_DB'} ) {
    $self->{'KILL_LIST_DB'} = {};
  }
  if ( $db_params ) {
    $self->{'KILL_LIST_DB'} = $db_params; 
  }
  return $self->{'KILL_LIST_DB'};
}



=head2

  Arg[1]      :
  Example     :
  Description :
  Return type :
  Exceptions  :
  Caller      :
  Status      :

=cut
sub FILTER_PARAMS {
  my ($self, $filter_params) = @_;

  if ( !$self->{'FILTER_PARAMS'} ) {
    $self->{'FILTER_PARAMS'} = {};
  }
  if ( $filter_params ) {
    throw("Must pass KillList:FILTER_PARAMS a hashref not a ".$filter_params)
      unless(ref($filter_params) eq 'HASH');
    $self->{'FILTER_PARAMS'} = $filter_params;
  }
  return $self->{'FILTER_PARAMS'};
}

=head2

  Arg[1]      :
  Example     :
  Description :
  Return type :
  Exceptions  :
  Caller      :
  Status      :

=cut
#sub read_and_check_config {
#  my ($self, $var_hash) = @_;
#  parse_config($self, $var_hash, $self->type);
#  ##########
#  # CHECKS
#  ##########
#  my $type = $self->type;
#
#  # check that compulsory options have values
#  foreach my $config_var (qw(GB_REF_DB
#                             KILL_LIST_DB 
#                             FILTER_PARAMS)) {
#    if (not defined $self->$config_var) {
#      throw("You must define $config_var in config for type '$type'")
#    }
#  }
#
#  # kill_list db has to be defined and should be a hash
#  if (!defined $self->KILL_LIST_DB || ref($self->KILL_LIST_DB) ne "HASH") {
#    throw("KILL_LIST_DB in config for '$type' must be defined and a hash ref of db connection pars.")
#  }
#  #reference db has to be defined and should be a hash
#  if (!defined $self->GB_REF_DB || ref($self->GB_REF_DB) ne "HASH") {
#    throw("GB_REF_DB in config for '$type' must be defined and a hash ref of db connection pars.")
#  }
#
#  # filter does not have to be defined, but if it is, it should
#  # give details of an object and its parameters
#  if ($self->FILTER) {
#    if (not ref($self->FILTER) eq "HASH" or
#        not exists($self->FILTER->{OBJECT}) or
#        not exists($self->FILTER->{PARAMETERS})) {
#
#      throw("FILTER in config fo '$logic' must be a hash ref with elements:\n" .
#            "  OBJECT : qualified name of the filter module;\n" .
#            "  PARAMETERS : anonymous hash of parameters to pass to the filter");
#    } else {
#      my $module = $self->FILTER->{OBJECT};
#      my $pars   = $self->FILTER->{PARAMETERS};
#
#      (my $class = $module) =~ s/::/\//g;
#      eval{
#        require "$class.pm";
#      };
#      throw("Couldn't require ".$class." Exonerate2Genes:require_module $@") if($@);
#
#      $self->filter($module->new(%{$pars}));
#    }
#  }

#}

=head2

  Arg[1]      :  $db, the kill_list database 
  Arg[2]      :  $filter_options - an array
                 (maybe better as a hash or Filter obj)  
                 specifying how to filter the kill_list.
  Example     :  my %kill_list = %{Bio::EnsEMBL::Analysis::Tools::KillListUtils::get_kill_list($kill_list_db, $filter_options)};
  Description :
  Return type :  Kill_list hash where keys = accession
                 and values = kill_objects 
  Exceptions  :
  Caller      :
  Status      :

=cut
sub get_kill_list {
  my ($self) = @_;

  print "\nUsing kill-list-db : " . $self->KILL_LIST_DB->{"-dbname"} . " \@ " . $self->KILL_LIST_DB->{"-host"} . "\n";

  my $db = Bio::EnsEMBL::KillList::DBSQL::DBAdaptor->new( %{ $self->KILL_LIST_DB }) ;
  $db->dbc->disconnect_when_inactive(1);
  #get the kill_list filter
  my %filter_params = %{$self->FILTER_PARAMS};
#  foreach my $key (keys %filter_params) {
#    print $key." ".$filter_params{$key}."\n";
#    if (ref $filter_params{$key} eq 'ARRAY') {
#      foreach my $val (@{$filter_params{$key}}) {
#        print $val."\n";
#      }
#    }
#  }
  #my $filter = Bio::EnsEMBL::KillList::Filter->new(%filter_params);

  #get objects where required 
  my $source_spp = $db->get_SpeciesAdaptor->fetch_by_dbID($filter_params{'-source_species'}) if ($filter_params{'-source_species'});
  my $date = $filter_params{'-before_date'};
  my $status = $filter_params{'-having_status'};
  my $mol_type = $filter_params{'-only_mol_type'};

  say "get_kill_list, MOL TYPE: ".$mol_type;

  my (@reasons, @analyses, @species, @external_db_ids);
  foreach my $id (@{$filter_params{'-reasons'}}) {
    push @reasons, $db->get_ReasonAdaptor->fetch_by_why($id);
  }
  foreach my $logic (@{$filter_params{'-for_analyses'}}) {
    push @analyses, $db->get_AnalysisLiteAdaptor->fetch_by_logic_name($logic);
  }
  foreach my $id (@{$filter_params{'-for_species'}}) {
    push @species, $db->get_SpeciesAdaptor->fetch_by_dbID($id);
  }
  foreach my $id (@{$filter_params{'-for_external_db_ids'}}) {
    push @external_db_ids, $id;
  }

  my $user ;
  # I uncommented the 'get_uesrAdaptor as in production a user will be fetched for every entry in the killList, 
  # which gives too much overhead. user is not used in filter() anyway. but a fix would be good to lazy-load this.  
  #$user = $db->get_UserAdaptor->fetch_by_user_name($filter_params{'-user_name'}) if ($filter_params{'-user_name'});
  #make the filter
  my $filter = Bio::EnsEMBL::KillList::Filter->new(
               -user                    => $user,
               -from_source_species     => $source_spp,
               -before_date             => $date,
               -having_status           => $status,
               -only_mol_type           => $mol_type,
               -reasons                 => \@reasons,
               -for_analyses            => \@analyses,
               -for_species             => \@species,
               -for_external_db_ids     => \@external_db_ids,
              );


  # an array of kill_objects
  my $kill_adaptor = $db->get_KillObjectAdaptor;
  my $kill_objects = $kill_adaptor->fetch_KillObjects_by_Filter($filter);

  my %kill_object_hash;
  foreach my $ko (@{$kill_objects}) {
    $kill_object_hash{$ko->accession} = $ko;
    #print STDERR "got ".$ko->dbID." accesssion ".$ko->accession."\n";
  }
  $db->dbc->disconnect_when_inactive(1);
  return \%kill_object_hash;
}

=head2

  Arg[1]      :  $db, the reference database to be updated
  Example     :
  Description :  Deletes any previous similar entries in the
                 meta table and adds a new entry, with 
                 meta_key = 'kill_list' and meta_value = now().
  Return type :  None
  Exceptions  :  None
  Caller      :
  Status      :

=cut
sub update_meta_table {
  my ($db) = @_;

  my $sth = $db->dbc->prepare(
            "DELETE FROM meta ".
            "WHERE meta_key = 'kill_list'");
  $sth->execute;
  $sth->finish;

  $sth = $db->dbc->prepare(
            "INSERT INTO meta ".
            "(meta_key, meta_value) ".
            "VALUES ('kill_list', now())");
  $sth->execute;
  $sth->finish;

  return;
}

1;
