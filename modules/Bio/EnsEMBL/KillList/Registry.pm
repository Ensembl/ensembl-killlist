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

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Registry

=head1 SYNOPSIS

Bio::EnsEMBL::Registry->load_all("configuration_file");

$gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor("homo_sapiens","core","gene"))


=head1 DESCRIPTION

All Adaptors are stored/registered using this module. This module should then
be used to get the adaptors needed.

The registry can be loaded from a configuration file using the method load_all.
If a file is passed to load_all then this is used.
Else if the enviroment variable ENSEMBL_REGISTRY is set then this is used
Else if the file .ensembl_init in your home directory exist it is used.

For the Web server ENSEMBL_REGISTRY should be set in SiteDefs.pm, which will
pass this on to load_all.


The registry can also be loaded via the method load_registry_from_db which
given a host will load the latest versions of the Ensembl databases from it.

The four types of registrys are for db adaptors, dba adaptors, dna adaptors
and the standard type.

=head2 db

These are registrys for backwards compatibillity and enable the subroutines
to add other adaptors to connections. 

e.g. get_all_db_adaptors, get_db_adaptor, add_db_adaptor, remove_db_adaptor
are the old DBAdaptor subroutines which are now redirected to the Registry.

So if before we had
   my $sfa = $self->adaptor()->db()->get_db_adaptor('blast');

We now want to change this to
   my $sfa = Bio::EnsEMBL::Registry->get_adaptor("Human","core","blast");


=head2 DBA

These are the stores for the DBAdaptors

The Registry will create all the DBConnections needed now if you set up the
configuration correctly. So instead of the old commands like

my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(....)
my $exon_adaptor = $db->get_ExonAdaptor;

we should now have just

my  $exon_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Human","core","Exon");


=head2 DNA

This is an internal Registry and allows the configuration of a dnadb. 
An example here is to set the est database to get its dna data from the core database.

## set the est db to use the core for getting dna data.
#Bio::EnsEMBL::Utils::ConfigRegistry->
#                         dnadb_add("Homo Sapiens","core","Homo Sapiens","est");


=head2 adaptors

This is the registry for all the general types of adaptors like GeneAdaptor, ExonAdaptor, 
Slice Adaptor etc.

These are accessed by the get_adaptor subroutine i.e.

my  $exon_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Human","core","Exon");

=head1 CONTACT

Post questions to the Ensembl developer list: <ensembl-dev@ebi.ac.uk>


=head1 METHODS

=cut



package Bio::EnsEMBL::KillList::Registry;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::ConfigRegistry;
use DBI;

use vars qw(%registry_register);

my $API_VERSION = 41;

=head2 load_all

 Will load the registry with the configuration file which is obtained from
 the first in the following and in that order.

  1) if an argument is passed to this method this is used as the conf file.
  2) If the enviroment variable ENSEMBL_REGISTRY is set this is used.
  3) If the file .ensembl_init exist in the home directory it is used

  Arg [1]    : (optional) string $arg file to load the registry from
  Arg [2]    : (optional) string if set prints out messages about conf file used.
  Arg [3]    : (optional) string if not 0 will print out all information
  Example    : Bio::EnsEMBL::Registry->load_all();
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut
 
sub load_all{
  my $class = shift;
  my $conf_file = shift;
  my $verbose = shift;
  
  if(defined($registry_register{'seen'})){
    print STDERR "Clearing previuosly loaded configuration from Registry\n" if ($verbose);
    $class->clear();
  }
  $registry_register{'seen'}=1;
  if(defined($conf_file)){
    print STDERR  "Loading conf from site defs file ".$conf_file."\n" if ($verbose);
;
    if(-e $conf_file){
      eval{ require($conf_file) }; $@ && die($@);
      
      # other wise it gets done again by the web initialisation stuff
      delete $INC{$conf_file}; 
    }
    else{ #error message
      print STDERR "File passed (".$conf_file.") does not exist therefore no configuration loaded\n";
    }
  }
  elsif(defined($ENV{ENSEMBL_REGISTRY}) and -e $ENV{ENSEMBL_REGISTRY}){
    my $file = $ENV{ENSEMBL_REGISTRY};
    print STDERR  "Loading conf from ".$file."\n"  if ($verbose);
;
    eval{ require($file) }; $@ && die($@);
  }
  elsif(-e $ENV{HOME}."/.ensembl_init") {
    my $file = $ENV{HOME}."/.ensembl_init";
    
    eval{ require($file) }; $@ && die($@)
  }
  else{
    print STDERR "NO default configuration to load\n" if ($verbose);
  }
}


=head2 clear

 Will clear the registry and disconnect from all databases.

  Example    : Bio::EnsEMBL::Registry->clear();
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub clear{
  my ($self);
  
  foreach my $dba (@{$registry_register{'_DBA'}}){
    if($dba->dbc->connected){
      $dba->dbc->db_handle->disconnect();
    }
  }
  %registry_register = ();
}

#
# db adaptors. (for backwards compatibillity)
#

=head2 add_db

  Arg [1]    : db (DBAdaptor) to add adaptor to.
  Arg [2]    : name of the name to add the adaptor to in the registry.
  Arg [3]    : The adaptor to be added to the registry.
  Example    : Bio::EnsEMBL::Registry->add_db($db, "lite", $dba);
  Returntype : none
  Exceptions : none
  Status     : At Risk.
             : This is here for backwards compatibillity only and may be removed 
             : eventually. Solution is to make sure the db and the adaptor have
             : the same species and the call is then no longer needed.
             
=cut

sub add_db{
  my ($class, $db, $name, $adap) = @_;


  if(lc($db->species()) ne lc($adap->species)){
    $registry_register{lc($db->species())}{lc($db->group())}{'_special'}{lc($name)} = $adap;
  }
}

=head2 remove_db

  Arg [1]    : db (DBAdaptor) to remove adaptor from.
  Arg [2]    : name to remove the adaptor from in the registry.
  Example    : my $db = Bio::EnsEMBL::Registry->remove_db($db, "lite");
  Returntype : adaptor
  Exceptions : none
  Status     : At Risk.
             : This is here for backwards compatibillity only and may be removed 
             : eventually. Solution is to make sure the db and the adaptor have
             : the same species and the call is then no longer needed.

=cut

sub remove_db{
  my ($class, $db, $name) = @_;

  my $ret = $registry_register{lc($db->species())}{lc($db->group())}{'_special'}{lc($name)};
  $registry_register{lc($db->species())}{lc($db->group())}{'_special'}{lc($name)} = undef;

  return $ret;
}

=head2 get_db

  Arg [1]    : db (DBAdaptor) to get adaptor from.
  Arg [2]    : name to get the adaptor for in the registry.
  Example    : my $db = Bio::EnsEMBL::Registry->get_db("Human", "core", "lite");
  Returntype : adaptor
  Exceptions : none
  Status     : At Risk.
             : This is here for backwards compatibillity only and may be removed 
             : eventually. Solution is to make sure the db and the adaptor have
             : the same species then call get_DBAdaptor instead.

=cut

sub get_db{
  my ($class, $db, $name) = @_;

  my $ret = Bio::EnsEMBL::Registry->get_DBAdaptor(lc($db->species),lc($name));

  if(defined($ret)){
    return $ret;
  }
  return $registry_register{lc($db->species())}{lc($db->group())}{'_special'}{lc($name)};
}

=head2 get_all_db_adaptors

  Arg [1]    : db (DBAdaptor) to get all the adaptors from.
  Example    : my $db = Bio::EnsEMBL::Registry->get_all_db_adaptors($db);
  Returntype : adaptor
  Exceptions : none
  Status     : At Risk.
             : This is here for backwards compatibillity only and may be removed 
             : eventually. Solution is to make sure the dbs all have
             : the same species then call get_all_DBAdaptors(-species => "human");


=cut

sub get_all_db_adaptors{
  my ($class,$db) = @_;
  my %ret=();

# we now also want to add all the DBAdaptors for the same species.
# as add_db_adaptor does not add if it is from the same species.

  foreach my $dba (@{$registry_register{'_DBA'}}){
    if(lc($dba->species()) eq lc($db->species())){
      $ret{$dba->group()} = $dba;
    } 
  }

 foreach my $key (keys %{$registry_register{$class->get_alias($db->species())}{lc($db->group())}{'_special'}}){
   $ret{$key} = $registry_register{$class->get_alias($db->species())}{lc($db->group())}{'_special'}{$key};
 }

  return \%ret;
}


#
# DBAdaptors
#

=head2 add_DBAdaptor

  Arg [1]    : name of the species to add the adaptor to in the registry.
  Arg [2]    : name of the group to add the adaptor to in the registry.
  Arg [3]    : The DBAaptor to be added to the registry.
  Example    : Bio::EnsEMBL::Registry->add_DBAdaptor("Human", "core", $dba);
  Returntype : none
  Exceptions : none
  caller     : internal
  Status     : Stable

=cut

sub add_DBAdaptor{
  my ($class, $species, $group, $adap) = @_;

  if(!($class->alias_exists($species))){
    $class->add_alias($species,$species);
  }
  

  $species = $class->get_alias($species);

  $registry_register{$species}{lc($group)}{'_DB'} = $adap;

  if(!defined($registry_register{'_DBA'})){
    my @list =();
    push(@list,$adap);
    $registry_register{'_DBA'}= \@list;
  }
  else{
    push(@{$registry_register{'_DBA'}},$adap);
  }

}



=head2 get_DBAdaptor

  Arg [1]    : name of the species to get the adaptor for in the registry.
  Arg [2]    : name of the group to get the adaptor for in the registry.
  Example    : $dba = Bio::EnsEMBL::Registry->get_DBAdaptor("Human", "core");
  Returntype : DBAdaptor
  Exceptions : none
  Status     : Stable

=cut

sub get_DBAdaptor{
  my ($class, $species, $group) = @_;

  $species = $class->get_alias($species);

  return  $registry_register{$species}{lc($group)}{'_DB'};

}

=head2 get_all_DBAdaptors

  Arg [SPECIES]: (optional) string 
                  species name to get adaptors for
  Arg [GROUP]  : (optional) string 
                  group name to get adaptors for
  Example      : @dba = @{Bio::EnsEMBL::Registry->get_all_DBAdaptors()};
               : @human_dbas = @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-species => 'human')};
  Returntype   : list of DBAdaptors
  Exceptions   : none
  Status       : Stable

=cut

sub get_all_DBAdaptors{
  my ($class,@args)=@_;
  my @ret;

  my ($species, $group) = 
    rearrange([qw(SPECIES GROUP)], @args);
  if(defined($species)){
    $species = $class->get_alias($species);
  }
  foreach my $dba (@{$registry_register{'_DBA'}}){
    if(!defined($species) || lc($species) eq lc($dba->species)){
      if(!defined($group) || lc($group) eq lc($dba->group)){
	push @ret, $dba;
      }
    }
  }


  return \@ret;
}

=head2 get_all_DBAdaptors_by_connection

  Arg [1]    :dbconnection to use to find DBAdaptors
  Returntype : reference to list of DBAdaptors
  Exceptions : none.
  Example    : @dba = @{Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_connection($dbc);
  Status     : Stable

=cut

sub get_all_DBAdaptors_by_connection{
  my ($self, $dbc_orig) = @_;
  my @return;

  foreach my $dba ( @{$registry_register{'_DBA'}}){
    my $dbc = $dba->dbc;
    if($dbc && $dbc->can('equals') && $dbc->equals($dbc_orig)){
      push @return, $dba;
    }
  }
  return \@return;
}


#
# DNA Adaptors
#

=head2 add_DNAAdaptor

  Arg [1]    : name of the species to add the adaptor to in the registry.
  Arg [2]    : name of the group to add the adaptor to in the registry.
  Arg [3]    : name of the species to get the dna from
  Arg [4]    : name of the group to get the dna from
  Example    : Bio::EnsEMBL::Registry->add_DNAAdaptor("Human", "estgene", "Human", "core");
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub add_DNAAdaptor{
  my ($class, $species, $group, $dnadb_species, $dnadb_group) = @_;

  $species = $class->get_alias($species);
  $dnadb_species = $class->get_alias($dnadb_species);
  if($dnadb_group->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')){
    deprecated("");
  }
  else{
    $registry_register{$species}{lc($group)}{'_DNA'} = $dnadb_group;
    $registry_register{$species}{lc($group)}{'_DNA2'} = $dnadb_species;
  }
}

=head2 get_DNAAdaptor

  Arg [1]    : name of the species to get the adaptor for in the registry.
  Arg [2]    : name of the group to get the adaptor for in the registry.
  Example    : $dnaAdap = Bio::EnsEMBL::Registry->get_DNAAdaptor("Human", "core");
  Returntype : adaptor
  Exceptions : none
  Status     : Stable

=cut

sub get_DNAAdaptor{
  my ($class, $species, $group) = @_;

  $species = $class->get_alias($species);
  my $new_group = $registry_register{$species}{lc($group)}{'_DNA'};
  my $new_species = $registry_register{$species}{lc($group)}{'_DNA2'};
  if( defined $new_group ) {
    return  $class->get_DBAdaptor($new_species,$new_group);
  } else {
    return undef;
  }
}

#
# General Adaptors
#

=head2 add_adaptor

  Arg [1]    : name of the species to add the adaptor to in the registry.
  Arg [2]    : name of the group to add the adaptor to in the registry.
  Arg [3]    : name of the type to add the adaptor to in the registry.
  Arg [4]    : The DBAaptor to be added to the registry.
  Arg [5]    : (optional) if set okay to overwrite.
  Example    : Bio::EnsEMBL::Registry->add_adaptor("Human", "core", "Gene", $adap);
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable


=cut

sub add_adaptor{
  my ($class,$species,$group,$type,$adap, $reset)= @_;

  $species = $class->get_alias($species);

#
# Becouse the adaptors are not stored initially only there class paths when
# the adaptors are obtained we need to store these instead.
# It is not necessarily an error if the registry is overwritten without
# the reset set but it is an indication that we are overwriting a database
# which should be a warning for now
#

  if(defined($reset)){ # JUST REST THE HASH VALUE NO MORE PROCESSING NEEDED
    $registry_register{$species}{lc($group)}{lc($type)} = $adap;
    return;
  }
  if(defined($registry_register{$species}{lc($group)}{lc($type)})){ 
    #print STDERR ("Overwriting Adaptor in Registry for $species $group $type\n");
    $registry_register{$species}{lc($group)}{lc($type)} = $adap;
   return;
  }
  $registry_register{$species}{lc($group)}{lc($type)} = $adap;

  if(!defined ($registry_register{$species}{'list'})){
    my @list =();
    push(@list,$type);
    $registry_register{$species}{'list'}= \@list;
  }
  else{
    push(@{$registry_register{$species}{'list'}},$type);
  }



  if(!defined ($registry_register{lc($type)}{$species})){
    my @list =();
    push(@list,$adap);
    $registry_register{lc($type)}{$species}= \@list;
  }
  else{
    push(@{$registry_register{lc($type)}{$species}},$adap);
  }

}


=head2 get_adaptor

  Arg [1]    : name of the species to add the adaptor to in the registry.
  Arg [2]    : name of the group to add the adaptor to in the registry.
  Arg [3]    : name of the type to add the adaptor to in the registry.
  Example    : $adap = Bio::EnsEMBL::Registry->get_adaptor("Human", "core", "Gene");
  Returntype : adaptor
  Exceptions : none
  Status     : Stable

=cut

sub get_adaptor{
  my ($class,$species,$group,$type)= @_;
 
  $species = $class->get_alias($species);
  my %dnadb_adaptors = qw(sequence  1 assemblymapper 1  karyotypeband 1 repeatfeature 1 coordsystem 1  assemblyexceptionfeature 1 );

  my $dnadb_group =  $registry_register{$species}{lc($group)}{_DNA};

  if( defined($dnadb_group) && defined($dnadb_adaptors{lc($type)}) ) {
      $species = $registry_register{$species}{lc($group)}{'_DNA2'};
      $group = $dnadb_group;
  }

  my $ret = $registry_register{$species}{lc($group)}{lc($type)};
  if(!defined($ret)){
    return undef;
  }
  if(!ref($ret)){ # not instantiated yet
    my $dba = $registry_register{$species}{lc($group)}{'_DB'};
    my $module = $ret;
    eval "require $module";

    if($@) {
      warning("$module cannot be found.\nException $@\n");
      return undef;
    }
    if(!defined($registry_register{$species}{lc($group)}{'CHECKED'})){
      $registry_register{$species}{lc($group)}{'CHECKED'} = 1;
      $class->version_check($dba);
    }
    my $adap = "$module"->new($dba);
    Bio::EnsEMBL::Registry->add_adaptor($species, $group, $type, $adap, "reset");
    $ret = $adap;
  }

  return $ret;
}

=head2 get_all_adaptors

  Arg [SPECIES] : (optional) string 
                  species name to get adaptors for
  Arg [GROUP] : (optional) string 
                  group name to get adaptors for
  Arg [TYPE] : (optional) string 
                  type to get adaptors for
  Example    : @adaps = @{Bio::EnsEMBL::Registry->get_all_adaptors()};
  Returntype : ref to list of adaptors
  Exceptions : none
  Status     : Stable

=cut

sub get_all_adaptors{
  my ($class,@args)= @_;
  my ($species, $group, $type);
  my @ret=();
  my (%species_hash, %group_hash, %type_hash);


  if(@args == 1){ #old species only one parameter
    warn("-SPECIES argument should now be used to get species adaptors");
    $species = $args[0];
  }
  else{
    # new style -SPECIES, -GROUP, -TYPE
    ($species, $group, $type) =
      rearrange([qw(SPECIES GROUP TYPE)], @args);
  }

  if(defined($species)){
    $species_hash{$species} = 1;
  }
  else{
    # get list of species
    foreach my $dba (@{$registry_register{'_DBA'}}){
      $species_hash{lc($dba->species())} = 1;
    }
  }
  if(defined($group)){
    $group_hash{$group} = 1;
  }
  else{
    foreach my $dba (@{$registry_register{'_DBA'}}){
      $group_hash{lc($dba->group())} = 1;
    }
  }
  if(defined($type)){
    $type_hash{$type} =1;
  }
  else{
    foreach my $dba (@{$registry_register{'_DBA'}}){ 
	foreach my $ty (@{$registry_register{lc($dba->species)}{'list'}}){
	  $type_hash{lc($ty)} = 1;
	}
      }
  }
  
  ### NOW NEED TO INSTANTIATE BY CALLING get_adaptor
  foreach my $sp (keys %species_hash){
    foreach my $gr (keys %group_hash){
      foreach my $ty (keys %type_hash){
	my $temp = $class->get_adaptor($sp,$gr,$ty);
	if(defined($temp)){
	  push @ret, $temp;
	}
      }
    }
  }
  return (\@ret);
}


=head2 add_alias

  Arg [1]    : name of the species to add alias for
  Arg [2]    : name of the alias
  Example    : Bio::EnsEMBL::Registry->add_alias("Homo Sapiens","Human");
  Description: add alternative name for the species.
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub add_alias{
  my ($class, $species,$key) = @_;

  $registry_register{'_ALIAS'}{lc($key)} = lc($species);
}

=head2 get_alias

  Arg [1]    : name of the possible alias to get species for
  Example    : Bio::EnsEMBL::Registry->get_alias("Human");
  Description: get proper species name.
  Returntype : species name
  Exceptions : none
  Status     : Stable

=cut

sub get_alias{
  my ($class, $key) = @_;

  if(!defined($registry_register{'_ALIAS'}{lc($key)})){
    return $key;
  }
  return $registry_register{'_ALIAS'}{lc($key)};
}

=head2 alias_exists

  Arg [1]    : name of the possible alias to get species for
  Example    : Bio::EnsEMBL::Registry->alias_exists("Human");
  Description: does the species name exist.
  Returntype : 1 if exists else 0
  Exceptions : none
  Status     : Stable

=cut

sub alias_exists{
  my ($class, $key) = @_;

  if(defined($registry_register{'_ALIAS'}{lc($key)})){
    return 1;
  }
  return 0;
}

=head2 set_disconnect_when_inactive

  Example    : Bio::EnsEMBL::Registry->set_disconnect_when_inactive();
  Description: Set the flag to make sure that the database connection is dropped if
               not being used on each database.
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub set_disconnect_when_inactive{
  foreach my $dba ( @{get_all_DBAdaptors()}){
    my $dbc = $dba->dbc;
    #disconnect if connected
    $dbc->disconnect_if_idle() if $dbc->connected();
    $dbc->disconnect_when_inactive(1);
  }
}


=head2 disconnect_all

  Example    : Bio::EnsEMBL::Registry->disconnect_all();
  Description: disconnect from all the databases.
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub disconnect_all {
  foreach my $dba ( @{get_all_DBAdaptors()||[]} ){
    my $dbc = $dba->dbc;
    next unless $dbc;
    #disconnect if connected
    $dbc->disconnect_if_idle() if $dbc->connected();
  }
}

=head2 change_access

  Will change the username and password for a set of databases.
  if host,user or database names are missing then these are not checked.
  So for example if you do not specify a database then ALL databases on
  the specified  host and port will be changed.

  Arg [1]    : name of the host to change access on
  Arg [2]    : port number to change access on
  Arg [3]    : name of the user to change access on
  Arg [4]    : name of the database to change access on
  Arg [5]    : name of the new user
  Arg [6]    : new password

  Example    : Bio::EnsEMBL::Registry->get_alias("Human");
  Description: change username and password on one or more databases
  Returntype : none
  Exceptions : none
  Status     : Stable

=cut

sub change_access{
my $self = shift;
    my ($host,$port,$user,$dbname,$new_user,$new_pass) = @_;
    foreach my $dba ( @{$registry_register{'_DBA'}}){
	my $dbc = $dba->dbc;
	if((!defined($host) or $host eq $dbc->host) and
	   (!defined($port) or $port eq $dbc->port) and
	   (!defined($user) or $user eq $dbc->username) and
	   (!defined($dbname) or $dbname eq $dbc->dbname)){
	    if($dbc->connected()){
		$dbc->db_handle->disconnect();
		$dbc->connected(undef);
	    }
	    # over write the username and password
	    $dbc->username($new_user);
	    $dbc->password($new_pass);
	}
    }
}



=head2 load_registry_from_db

  Arg [HOST] : The domain name of the database host to connect to.
               
  Arg [USER] : string
               The name of the database user to connect with
  Arg [PASS] : (optional) string
               The password to be used to connect to the database
  Arg [PORT] : int
               The port to use when connecting to the database
  Arg [VERBOSE]: (optional) Wether to print database messages 

  Example : load_registry_from_db( -host => 'ensembldb.ensembl.org',
				   -user => 'anonymous',
				   -verbose => "1" );

  Description: Will load the correct versions of the ensembl databases for the
               software release it can find on a database instance into the 
               registry. Also adds a set of standard aliases.

  Exceptions : None.
  Status     : Stable
 
=cut

sub load_registry_from_db{
  my($self, @args) = @_;
  my ($host, $port, $user, $pass, $verbose) =
    rearrange([qw(HOST PORT USER PASS VERBOSE)], @args);



  my $go_version = 0;
  my $compara_version =0;
  my $ensembl_kill_list_version = 0;

  $user ||= "ensro";
  $port ||= 3306;
  my $db = DBI->connect( "DBI:mysql:host=$host;port=$port" , $user, $pass );

  my $res = $db->selectall_arrayref( "show databases" );
  my @dbnames = map {$_->[0] } @$res;
  
  my %temp;
  my $software_version = $self->software_version();
  print "Will only load $software_version databases\n" if ($verbose);
  for my $db (@dbnames){
    if($db =~ /^([a-z]+_[a-z]+_[a-z]+)_(\d+)_(\d+[a-z]*)/){
      if($2 eq $software_version){
	$temp{$1} = $2."_".$3;
      }
    }
    elsif($db =~ /^ensembl_compara_(\d+)/){
      if($1 eq $software_version){
	$compara_version = $1;
      }
    }
    elsif($db =~ /^ensembl_go_(\d+)/){
      if($1 eq $software_version){
	$go_version = $1;
      }
    }
    elsif($db =~ /^gb_kill_list_(\d+)/){
      if($1 eq $software_version){
        $ensembl_kill_list_version = $1;
      }
    }
  }
  
  @dbnames =();
  
  foreach my $key ( keys %temp){
    push @dbnames, $key."_".$temp{$key};
  }	 
  # register core databases
  
  my @core_dbs = grep { /^[a-z]+_[a-z]+_core_\d+_/ } @dbnames;
  
  for my $coredb ( @core_dbs ) {
    my ($species, $num ) = ( $coredb =~ /(^[a-z]+_[a-z]+)_core_(\d+)/ );
    my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new
      ( -group => "core",
	-species => $species,
	-host => $host,
	-user => $user,
	-pass => $pass,
	-port => $port,
	-dbname => $coredb
      );
    (my $sp = $species ) =~ s/_/ /g;
    $self->add_alias( $species, $sp );
    print $coredb." loaded\n" if ($verbose);
  }

  my @vega_dbs = grep { /^[a-z]+_[a-z]+_vega_\d+_/ } @dbnames;
  
  for my $vegadb ( @vega_dbs ) {
    my ($species, $num ) = ( $vegadb =~ /(^[a-z]+_[a-z]+)_vega_(\d+)/ );
    my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new
      ( -group => "vega",
	-species => $species,
	-host => $host,
	-user => $user,
	-pass => $pass,
	-port => $port,
	-dbname => $vegadb
      );
    (my $sp = $species ) =~ s/_/ /g;
    $self->add_alias( $species, $sp );
    print $vegadb." loaded\n" if ($verbose);
  }
  
  my @other_dbs = grep { /^[a-z]+_[a-z]+_otherfeatures_\d+_/ } @dbnames;
  
  for my $other_db ( @other_dbs ) {
    my ($species, $num) = ( $other_db =~ /(^[a-z]+_[a-z]+)_otherfeatures_(\d+)/ );
    my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new
      ( -group => "otherfeatures",
	-species => $species,
	-host => $host,
	-user => $user,
	-pass => $pass,
	-port => $port,
	-dbname => $other_db
      );
      (my $sp = $species ) =~ s/_/ /g;
      $self->add_alias( $species, $sp );
      print $other_db." loaded\n" if ($verbose);       
  }
  
  
  eval "require Bio::EnsEMBL::Variation::DBSQL::DBAdaptor";
  if($@) {
    #ignore variations as code required not there for this
    print "Bio::EnsEMBL::Variation::DBSQL::DBAdaptor module not found so variation databases will be ignored if found\n" if ($verbose);
  }
  else{
    my @variation_dbs = grep { /^[a-z]+_[a-z]+_variation_\d+_/ } @dbnames;
    
    for my $variation_db ( @variation_dbs ) {
      my ($species, $num ) = ( $variation_db =~ /(^[a-z]+_[a-z]+)_variation_(\d+)/ );
      my $dba = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new
	( -group => "variation",
	  -species => $species,
	  -host => $host,
	  -user => $user,
	  -pass => $pass,
	  -port => $port,
	  -dbname => $variation_db
	);
      print $variation_db." loaded\n" if ($verbose);
    }
  }

  eval "require Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor";
  if($@) {
    #ignore funcgen DBs as code required not there for this
	  print "Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor module not found so functional genomics databases will be ignored if found\n" if ($verbose);
  }
  else{
    my @funcgen_dbs = grep { /^[a-z]+_[a-z]+_funcgen_\d+_/ } @dbnames;
    
    for my $funcgen_db ( @funcgen_dbs ) {
		my ($species, $num ) = ( $funcgen_db =~ /(^[a-z]+_[a-z]+)_funcgen_(\d+)/ );
		my $dba = Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor->new
		  ( -group => "funcgen",
			-species => $species,
			-host => $host,
			-user => $user,
			-pass => $pass,
			-port => $port,
			-dbname => $funcgen_db
		  );
		print $funcgen_db." loaded\n" if ($verbose);
    }
  }

  
  #Compara
  if($compara_version){
    eval "require Bio::EnsEMBL::Compara::DBSQL::DBAdaptor";
    if($@) {
      #ignore compara as code required not there for this
      print "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor not found so compara database ensembl_compara_$compara_version will be ignored\n" if ($verbose);
    }
    else{
      my $compara_db = "ensembl_compara_".$compara_version;

      my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
	( -group => "compara",
	  -species => "multi",
	  -host => $host,
	  -user => $user,
	  -pass => $pass,
	  -port => $port,
	  -dbname => $compara_db
	);
      print $compara_db." loaded\n" if ($verbose);       
    }
  }
  else{
    print "No Compara database found" if ($verbose);
  }


  #GO
  if($go_version){
    eval "require Bio::EnsEMBL::ExternalData::GO::GOAdaptor";
    if($@) {
      #ignore go as code required not there for this
#      print $@;
      print "GO software not installed so go database ensemb_go_$go_version will be ignored\n" if ($verbose);
    }
    else{
      my $go_db = "ensembl_go_".$go_version;
      my $dba = Bio::EnsEMBL::ExternalData::GO::GOAdaptor->new
	( -group => "go",
	  -species => "multi",
	  -host => $host,
	  -user => $user,
	  -pass => $pass,
	  -port => $port,
	  -dbname => $go_db
	);
      print $go_db." loaded\n" if ($verbose);              
    }
  }
  else{
    print "No go database found" if ($verbose);
  }

  # Ensembl Kill List
  if($ensembl_kill_list_version){
    eval "require Bio::EnsEMBL::KillList::DBSQL::DBAdaptor";
    if($@) {
      #ignore go as code required not there for this
#      print $@;
      print "Ensembl Kill List software not installed so go database ensembl_kill_list_$ensembl_kill_list_version will be ignored\n" if ($verbose);
    }
    else{
      my $ensembl_kill_list_db = "ensembl_kill_list_".$ensembl_kill_list_version;
      my $dba = Bio::EnsEMBL::KillList::DBSQL::DBAdaptor->new
        ( -group => "ensembl_kill_list",
          -species => "multi",
          -host => $host,
          -user => $user,
          -pass => $pass,
          -port => $port,
          -dbname => $ensembl_kill_list_db
        );
      print $ensembl_kill_list_db." loaded\n" if ($verbose);
    }
  }
  else{
    print "No ensembl_kill_list database found" if ($verbose);
  }

  #hard coded aliases for the different species

  my @aliases = ('chimp','PanTro1', 'Pan', 'P_troglodytes');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Pan_troglodytes",
						 -alias => \@aliases);
  
  @aliases = ('elegans');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Caenorhabditis_elegans", 
						 -alias => \@aliases);
  
  @aliases = ('tetraodon');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Tetraodon_nigroviridis",
						 -alias => \@aliases);
  
  @aliases = ('H_Sapiens', 'homo sapiens', 'Homo_Sapiens', 'Homo', 'human', 'Hg17','ensHS', '9606');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Homo_sapiens",
						 -alias => \@aliases);
  
  @aliases = ('M_Musculus', 'mus musculus', 'Mus_Musculus', 'Mus', 'mouse','Mm5','ensMM','10090');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Mus_musculus",
						 -alias => \@aliases);
  
  @aliases = ('R_Norvegicus', 'rattus norvegicus', 'Rattus_Norvegicus', 'Rattus', 'rat', 'Rn3', '10116');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Rattus_norvegicus",
                                               -alias => \@aliases);
  
  @aliases = ('F_Rubripes', 'fugu rubripes', 'Fugu_Rubripes', 'Fugu');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Fugu_rubripes",
						 -alias => \@aliases);
  
  @aliases = ('G_Gallus', 'gallus gallus', 'Gallus_gallus', 'Chicken', 'GalGal2');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Gallus_Gallus",
						 -alias => \@aliases);
  
  @aliases = ('D_Rerio', 'danio rerio', 'Danio_Rerio', 'Danio', 'zebrafish', 'zfish');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Danio_rerio",
						 -alias => \@aliases);
  
  @aliases = ('X_Tropicalis', 'xenopus tropicalis','Xenopus_tropicalis', 'Xenopus');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Xenopus_tropicalis",
						 -alias => \@aliases);
  
  @aliases = ('A_Gambiae', 'Anopheles Gambiae','Anopheles_gambiae', 'Anopheles','mosquito');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Anopheles_gambiae",
						 -alias => \@aliases);
  
  @aliases = ('A_Mellifera', 'Apis Mellifera','Apis_mellifera', 'Apis', 'honeybee');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Apis_mellifera",
						 -alias => \@aliases);
  
  @aliases = ('D_Melanogaster', 'drosophila melanogaster', 'Drosophila_melanogaster', 'drosophila', 'fly');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Drosophila_melanogaster",
						 -alias => \@aliases);
  
  @aliases = ('S_Cerevisiae', 'Saccharomyces Cerevisiae', 
	      'Saccharomyces_cerevisiae', 'Saccharomyces', 'yeast');
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Saccharomyces_cerevisiae",
						 -alias => \@aliases);

  @aliases = ('C_Familiaris', 'Canis Familiaris', 
	      'Canis_familiaris', 'Canis', 'dog');
  
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Canis_familiaris",
						 -alias => \@aliases);
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Ciona_intestinalis",
						 -alias => ['ciona']);
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "Bos_taurus",
						 -alias => ['cow']);
  @aliases = ('compara');
  
  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "multi",
						 -alias => \@aliases);

  @aliases = ('kill_list');  

  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(-species => "multi",
                                                 -alias => \@aliases);
}


#
# Web specific routines
#



=head2 DEPRECATED load_registry_with_web_adaptors

  DEPRECATED: Use load_registry_from_db instead.

=cut

sub load_registry_with_web_adaptors{
  my $class = shift;

  deprecate('Use the load_registry_from_db instead'); 
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
    SiteDefs->import(qw(:ALL));

  eval{ require SpeciesDefs };
  if ($@){ die "Can't use SpeciesDefs.pm - $@\n"; }
  my $conf = new SpeciesDefs();
  
  my %species_alias = %{$SiteDefs::ENSEMBL_SPECIES_ALIASES};

  foreach my $spec (keys %species_alias){
    Bio::EnsEMBL::Registry->add_alias($species_alias{$spec},$spec);
  }

}

=head2 set_default_track

  Sets a flag to say that that this species/group are a default track and do not
  need to be added as another web track.

  Arg [1]    : name of the species to get the adaptors for in the registry.
  Arg [2]    : name of the type to get the adaptors for in the registry.
  Example    : $merged = Bio::EnsEMBL::Registry->set_default_track("Human","core");
  Returntype : none
  Exceptions : none
  Status     : At Risk.

=cut

sub set_default_track{
  my ($class, $species, $group) = @_;  

  $species = get_alias($species);
  $registry_register{'def_track'}{$species}{lc($group)} = 1;
}

=head2 default_track

  Check flag to see if this is a default track

  Arg [1]    : name of the species to get the adaptors for in the registry.
  Arg [2]    : name of the type to get the adaptors for in the registry.
  Example    : $merged = Bio::EnsEMBL::Registry->set_default_track("Human","core");
  Returntype : int 
  Exceptions : none
  Status     : At Risk.

=cut

sub default_track{
  my ($class, $species, $group) = @_;  

  $species = get_alias($species);
  if(defined($registry_register{'def_track'}{$species}{lc($group)})){
    return 1;
  }
  
  return 0;
}


=head2 add_new_tracks

  Will add new gene tracks to the configuration of the WEB server if they are
  not of the type default and the configuration already has genes in the display.

  Arg [1]    : hash of the default configuration of the web page
  Returntype : none
  Exceptions : none
  Called by  : UserConfig.pm
  Status     : At Risk.
  
=cut

sub add_new_tracks{
  my($class, $conf, $pos) = @_;

  my $start = 0;
  my $reg = $class;
  my $species_reg = $reg->get_alias($conf->{'species'},"nothrow");
  my %pars;
#  print STDERR "Species $species_reg check for default tracks\n";
  if(defined($species_reg)){
    foreach my $dba (@{$reg->get_all_DBAdaptors()}){
      if(!$reg->default_track($dba->species,$dba->group)){
	$pars{'available'} = "species ".$reg->get_alias($dba->species());
	$pars{'db_alias'} = $dba->group();
#	print STDERR "Adding new track for ".$dba->species."\t".$dba->group."\n";
	$conf->add_new_track_generictranscript('',$dba->group(), "black",$pos,%pars);
	$pos++;
      }
    }
  }
  return $pos;

}

=head2 software_version
  
  get the software version.
  
  Args       : none
  ReturnType : int
  Status     : At Risk
  
=cut
  
sub software_version{
  my ($self) = @_;
  return $API_VERSION;
}
  
=head2 no_version_check
  
  getter/setter for whether to run the version checking
  
  Arg[0]     : (optional) int
  Returntype : int or undef if not set
  Exceptions : none
  Status     : At Risk.

=cut
  
sub no_version_check {
  my ($self, $arg ) = @_;
  ( defined $arg ) && ( $registry_register{'_no_version_check'} = $arg );
  return $registry_register{'_no_version_check'};
}

  
=head2 version_check
  
  run the database/API code version check for a DBAdaptor
  
  Arg[0]     : DBAdaptor to check
  Returntype : int 1 if okay, 0 if not the same 
  Exceptions : none
  Status     : At Risk.

=cut
  
  
sub version_check{
  my ($self, $dba) = @_;
  
  # Check the datbase and versions match
  # give warning if they do not.
  my $check = no_version_check();
  if( (defined($ENV{HOME}) and (-e $ENV{HOME}."/.ensemblapi_no_version_check"))
   or (defined($check) and ($check != 0))){
    return 1;
  }
  my $mca = $self->get_adaptor($dba->species(),$dba->group(),"MetaContainer");
  my $database_version = 0;
  if(defined($mca)){
    $database_version = $mca->get_schema_version();
  }
  if($database_version == 0){
    #try to work out the version
    if($dba->dbc->dbname() =~ /^_test_db_/){
      return 1;
    }
    if($dba->dbc->dbname() =~ /(\d+)_\S+$/){
      $database_version = $1;
    }
    elsif($dba->dbc->dbname() =~ /ensembl_compara_(\d+)/){
      $database_version = $1;
    }
    elsif($dba->dbc->dbname() =~ /ensembl_go_(\d+)/){
      $database_version = $1;
    }
    elsif($dba->dbc->dbname() =~ /ensembl_kill_list_(\d+)/){
      $database_version = $1;
    }
    elsif($dba->dbc->dbname() =~ /ensembl_help_(\d+)/){
      $database_version = $1;
    }
    else{
      warn("No database version for database ".$dba->dbc->dbname().". You must be using a pre version 34 database with version 34 or later code. You need to update your database or use the appropriate ensembl software release to ensure your script does not crash\n");
    }
  }
  if($database_version != $API_VERSION){
    warn("For ".$dba->dbc->dbname()." there is a difference in the software release (".$API_VERSION.") and the database release (".$database_version."). You should change one of these to ensure your script does not crash.\n");
    return 0;
  }
  else {
    return 1;
  }
}

1;
