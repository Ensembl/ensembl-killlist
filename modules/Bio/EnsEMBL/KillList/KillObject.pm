# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::KillList::KillObject;

use strict;
use warnings;
use Bio::EnsEMBL::Storable;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning);
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Storable);


sub new {
  my $caller = shift;

  my $class = ref($caller) || $caller;
  my $self = $class->SUPER::new(@_);

  my ($object_id, $mol_type, $taxonObj, $userObj,
      $accession, $version, $external_db_id,
      $description, $sequence, 
      $reasons, $analyses, $species_allowed, $comments,$kill_list_dbadaptor,$user_id,$taxon_id) = 
      rearrange( ['DBID','MOL_TYPE', 'TAXON', 'USER', 
                  'ACCESSION','VERSION','EXTERNAL_DB_ID',
                  'DESCRIPTION', 'SEQUENCE', 
                  "REASONS", "ANALYSES", "SPECIES_ALLOWED", 
                  "COMMENTS","KILL_LIST_DBADAPTOR","USER_ID","TAXON_ID"], @_ );


 if (!defined($mol_type)) {throw " ERROR: need to set -mol_type\n";}
 if (!defined($external_db_id)) {throw " ERROR: need to set -external_db_id\n";}
 #if (!defined($taxon)) {throw " ERROR: need to set -taxon\n";}  
 
 
 if (!defined($accession)) {throw " ERROR: need to set -accession\n";}

  if (!defined($mol_type)  || !defined($accession)  ||  !defined($external_db_id) ) {
    throw " ERROR: need to set -mol_type, -accession, -external_db_id  and -taxon ";
  }

  if ( $userObj ) {
    if(!ref($userObj) || !$userObj->isa('Bio::EnsEMBL::KillList::User')) { 
      throw("User has to be an Object of type Bio::EnsEMBL::KillList::User\n") ;  
    }
    $self->user($userObj); 
  } 

  if ( $user_id ) { 
     $self->user_id($user_id);     
  } 


  #my $sa = $self->db->get_SpeciesAdaptor();
  #print $sa . "\n";

  # setting kill list db adaptor to lazy-load user / taxon  
  if ( $kill_list_dbadaptor ) {  
    $self->kill_list_dbadaptor($kill_list_dbadaptor); 
  } 

  if ( $taxonObj ) { 
     if(!ref($taxonObj) || !$taxonObj->isa('Bio::EnsEMBL::KillList::Species')) {
       throw('-TAXON argument must be a Bio::EnsEMBL::Species not '.  $taxonObj);
     } else {  
       $self->taxon($taxonObj); 
     }  
  }
  if ( $taxon_id ) { 
     $self->taxon_id($taxon_id) ; 
  } 




  $self->mol_type( $mol_type );
  $self->accession( $accession );
  if ($reasons) {
    $self->{'_reason_array'} = $reasons;
  }
  $self->external_db_id( $external_db_id );

  $self->version( $version ) if ( defined $version );
  $self->description( $description ) if ( defined $description );
  $self->sequence( $sequence ) if ( defined $sequence );

  if ($analyses) {
    $self->{'_analysis_array'} = $analyses;
  } else {
    $self->{'_analysis_array'} = $self->get_all_Analyses_allowed();
  }

  if ($species_allowed) {
    $self->{'_species_allowed_array'} = $species_allowed;
  } else {
    $self->{'_species_allowed_array'} = $self->get_all_Species_allowed();
  }
 
  if ($comments) {
    $self->{'_comment_array'} = $comments;
  } else {
    $self->{'_comment_array'} = $self->get_all_Comments();;
  } 
  $self->dbID( $object_id ) if ( defined $object_id );

  return $self;
}


sub user {
  my ($self,$usr) = @_ ; 
  # setting user by argument  
  
  if($usr) { 
    if(!ref($usr) || !$usr->isa('Bio::EnsEMBL::KillList::User')) { 
      throw('user argument must be a Bio::EnsEMBL::User');
    }
    $self->{'user'} = $usr;
  } 


  unless ( $self->{'user'} ) {  
    if ( $self->user_id ) {  
      my $ua  =  $self->kill_list_dbadaptor()->get_UserAdaptor(); 
      my $user = $ua->fetch_by_dbID($self->user_id);  
      if ( $user ) { 
         $self->{'user'} = $user ;  
      } else { 
        throw("user with id " . $self->user_id . "  can't be found\n" ) ; 
      }
    }  
  }
  return $self->{'user'};
}

sub taxon {
  my (  $self, $spp ) = @_ ;  

  if(defined($spp) ) { 
     if (!ref($spp) || !$spp->isa('Bio::EnsEMBL::KillList::Species')) {
       throw('taxon argument must be a Bio::EnsEMBL::Species');
     } else { 
       $self->{'taxon'} = $spp;
    }  
  }

  # no taxon object but taxon_id  
  unless ( $self->{taxon} ) {  
    if ( $self->taxon_id ) { 
      my $sa  =  $self->kill_list_dbadaptor()->get_SpeciesAdaptor(); 
      my $taxonObj  = $sa->fetch_by_dbID($self->taxon_id) ; 
      if ( $taxonObj ) { 
         $self->{'taxon'} = $taxonObj ;  
      } else { 
        throw("Taxon with id " . $self->taxon_id. "  can't be found\n" ) ; 
      }
    }   
  }
  return $self->{'taxon'};
}

sub mol_type {
  my ($self,$type ) = @_ ;  

  if ( $type ) { 
    $self->{'mol_type'} = $type ;  
   } 
  return $self->{'mol_type'};
}

sub user_id {
  my ($self,$type ) = @_ ;  

  if ( $type ) { 
    $self->{'user_id'} = $type ;  
   } 
  return $self->{'user_id'};
} 


sub taxon_id {
  my ($self,$type ) = @_ ;  

  if ( $type ) { 
    $self->{'taxon_id'} = $type ;  
   } 
  return $self->{'taxon_id'};
}


sub kill_list_dbadaptor {
  my $self = shift;
  $self->{'kill_list_dbadaptor'} = shift if( @_ );
  return $self->{'kill_list_dbadaptor'};
}



sub accession {
  my $self = shift;
  $self->{'accession'} = shift if( @_ );
  return $self->{'accession'};
}

sub version {
  my $self = shift;
  $self->{'version'} = shift if( @_ );
  return $self->{'version'};
}

sub external_db_id {
  my $self = shift;
  $self->{'external_db_id'} = shift if( @_ );
  return $self->{'external_db_id'};
}
 
#sub get_external_db_name_from_id {
#  my $self = shift;
#  my $external_db_id = shift;
#  my $sth = $self->prepare(
#            "SELECT db_name ".
#            "FROM external_db ".
#            "WHERE external_db_id = ?"); 
#  $sth->execute();
#  my $external_db_name = $sth->fetchrow();
#  $sth->finish();
#  return $external_db_name;
#}  

sub description {
  my $self = shift;
  $self->{'description'} = shift if( @_ );
  return $self->{'description'};
}

sub sequence {
  my $self = shift;
   
  if (@_) {
    my $sequence = shift;
    if (defined($sequence) && (!ref($sequence) || !$sequence->isa('Bio::EnsEMBL::KillList::Sequence'))) {
      throw('Sequence argument must be a Bio::EnsEMBL::KillList::Sequence');
    }
    $self->{'sequence'} = $sequence;
  }
  return $self->{'sequence'};
}
 
sub current_status {
  my $self = shift;
  $self->{'_current_status'} = shift if( @_ );
  return $self->{'_current_status'};
}

sub timestamp {
  my $self = shift;
  $self->{'_timestamp'} = shift if( @_ );
  return $self->{'_timestamp'};
}

sub add_Comment {
  my ($self,$comment) = @_;

  unless(defined $comment && ref $comment && $comment->isa("Bio::EnsEMBL::KillList::Comment") ) {
    throw("[$comment] is not a Bio::EnsEMBL::KillList::Comment!");
  }

  $self->{'_comment_array'} ||= [];
  push @{$self->{'_comment_array'}}, $comment; 

}

sub get_all_Comments {
  my ($self) = @_;
  if (!defined $self->{'_comment_array'} && defined $self->adaptor()) {
    $self->{'_comment_array'} = $self->adaptor()->db()->get_CommentAdaptor()->fetch_all_by_KillObject($self);
  } 
  return $self->{'_comment_array'}; 
}

sub flush_Comments {
  my ($self,@args) = @_;
  $self->{'_comment_array'} = [];
}

sub add_Species_allowed {
  my ($self,$species_allowed) = @_;

  unless(defined $species_allowed && ref $species_allowed  
         && $species_allowed->isa("Bio::EnsEMBL::KillList::Species") ) {
    throw("[$species_allowed is not a Bio::EnsEMBL::KillList::Species!");
  }

  $self->{'_species_allowed_array'} ||= [];

  foreach my $already_added ( @{ $self->{_species_allowed_array} } ){
    # compare objects
    if ( $species_allowed->name eq  $already_added->name &&
         $species_allowed->taxon_id eq  $already_added->taxon_id && 
         $species_allowed->name_class eq  $already_added->name_class){
      #this feature has already been added
      return;
    }
  }
  push (@{$self->{'_species_allowed_array'}}, $species_allowed);
}

sub get_all_Species_allowed {
  my ($self) = @_;
  if (!defined $self->{'_species_allowed_array'} && defined $self->adaptor()) {
    $self->{'_species_allowed_array'} = $self->adaptor()->db()->get_SpeciesAdaptor()->fetch_all_by_KillObject($self);
  } 
  return $self->{'_species_allowed_array'};
}

sub flush_Species_allowed {
  my ($self,@args) = @_;
  $self->{'_species_allowed_array'} = [];
}

sub add_Reason {
  my ($self,$reason) = @_;

  unless(defined $reason && ref $reason 
         && $reason->isa("Bio::EnsEMBL::KillList::Reason")) {
    throw("Reason [$reason] not a " .
            "Bio::EnsEMBL::KillList::Reason");
  }

  $self->{'_reason_array'} ||= [];

  foreach my $already_added ( @{ $self->{_reason_array} } ){
    # compare objects
    if ( $reason->dbID == $already_added->dbID &&
         $reason->why  eq $already_added->why ){
      #this feature has already been added
      return;
    }
  }
  push (@{$self->{'_reason_array'}}, $reason);

}

sub get_all_Reasons {
  my ($self) = @_;
  if (!defined $self->{'_reason_array'} && defined $self->adaptor()) {
    $self->{'_reason_array'} = $self->adaptor()->db()->get_ReasonAdaptor()->fetch_all_by_KillObject($self);
  }
  return $self->{'_reason_array'};
}

sub flush_Reasons {
  my ($self,@args) = @_;
  $self->{'_reason_array'} = [];
}

sub add_Analysis_allowed {
  my ($self,$analysis) = @_;

  unless(defined $analysis && ref $analysis 
         && $analysis->isa("Bio::EnsEMBL::KillList::AnalysisLite")) {
    throw("Analysis [$analysis] not a " .
          "Bio::EnsEMBL::KillList::AnalysisLite");
  }

  $self->{'_analysis_array'} ||= [];

  foreach my $already_added ( @{ $self->{_analysis_array} } ){
    # compare objects
    if ( $analysis->logic_name  eq $already_added->logic_name  &&
         $analysis->dbID        == $already_added->dbID        && 
         $analysis->program     eq $already_added->program     &&
         $analysis->description eq $already_added->description ) {
      #this feature has already been added
      return;
    }
  }
  push @{$self->{'_analysis_array'}}, $analysis;  

}

sub get_all_Analyses_allowed {
  my ($self) = @_;
  if (!defined $self->{'_analysis_array'} && defined $self->adaptor()) {
    $self->{'_analysis_array'} = $self->adaptor()->db()->get_AnalysisLiteAdaptor()->fetch_all_by_KillObject($self);
  }
  return $self->{'_analysis_array'};
}

sub flush_Analyses_allowed {
  my ($self,@args) = @_;
  $self->{'_analysis_array'} = [];
}

sub _clone_KillObject {
  my ($self, $kill_object) = @_;

  # clone all of the objects attached to $kill_object
  # Yeah i know it would be easier to do:
  # $newkill_object->add_Species_allowed($kill_object->get_all_Species_allowed);
  # but i'm trying to be careful!

  my (@newreasons, @newspecies, @newanalyses, @newcomments);

  foreach my $reason (@{$kill_object->get_all_Reasons}) {
    my $newreason = Bio::EnsEMBL::KillList::Reason->_clone_Reason($reason);
    push @newreasons, $newreason;
  }
  foreach my $spp (@{$kill_object->get_all_Species_allowed}) {
    my $newspp = Bio::EnsEMBL::KillList::Species->_clone_Species($spp);
    push @newspecies, $newspp;
  }
  foreach my $analysis (@{$kill_object->get_all_Analyses_allowed}) {
    my $newanalysis = Bio::EnsEMBL::KillList::AnalysisLite->_clone_Analysis($analysis);
    push @newanalyses, $newanalysis;
  }
  foreach my $comment (@{$kill_object->get_all_Comments}) {
    my $newcomment = Bio::EnsEMBL::KillList::Comment->_clone_Comment($comment);
    push @newcomments, $newcomment;
  }

  # don't take the adaptor or dbID
  my $newkill_object = new Bio::EnsEMBL::KillList::KillObject(
                       -dbID            => $kill_object->dbID,
                       -user            => Bio::EnsEMBL::KillList::User->_clone_User($kill_object->user), 
                       -taxon           => Bio::EnsEMBL::KillList::Species->_clone_Species($kill_object->taxon),
                       -mol_type        => $kill_object->mol_type,
                       -accession       => $kill_object->accession,
                       -external_db_id  => $kill_object->external_db_id, 
                       -reasons         => \@newreasons, #,$kill_object->get_all_Reasons, 
                       -version         => $kill_object->version,
                       -analyses        => \@newanalyses, #$kill_object->get_all_Analyses_allowed,
                       -comments        => \@newcomments, # $kill_object->get_all_Comments,
                       -species_allowed => \@newspecies, #$kill_object->get_all_Species_allowed,
                       -description     => $kill_object->description ,
                       -sequence        => $kill_object->sequence,
                                                         );
  return $newkill_object;
}

sub remove_Analysis_allowed {
  my $kill_object = shift;
  my $analysis_to_remove = shift;
  my $clone = clone_KillObject($kill_object);

  my @current_analyses = @{$clone->get_all_Analyses_allowed};
  my @new_analyses;
  foreach my $analysis (@current_analyses) {
    if ($analysis != $analysis_to_remove) {
      push @new_analyses, $analysis; 
    }
  }

  $clone->flush_Analyses_allowed;
  foreach my $analysis (@new_analyses) { 
    $clone->add_Analysis_allowed($analysis); 
  }
  return $clone;
}

sub remove_Species_allowed {
  my $kill_object = shift;
  my $species_to_remove = shift;
  my $clone = clone_KillObject($kill_object);

  my @current_species = @{$clone->get_all_Species_allowed};
  my @new_species;
  foreach my $species (@current_species) {
    if ($species != $species_to_remove) {
      push @new_species, $species;
    }
  }

  $clone->flush_Species_allowed;
  foreach my $species (@new_species) {
    $clone->add_Species_allowed($species);
  }
  return $clone;
}

sub _identical {
  my ($self, $kill_object_A, $kill_object_B) = @_;
  my $identical;
  print STDERR "Comparing kill_objects (accessions ".$kill_object_A->accession." and ".$kill_object_B->accession.")\n";

  # check external_db_id, taxon, mol_type, accession, version
  # doesn't matter if user or description are the different
  if ( $kill_object_A->accession      eq $kill_object_B->accession      &&
       $kill_object_A->mol_type       eq $kill_object_B->mol_type       &&
       $kill_object_A->taxon->name    eq $kill_object_B->taxon->name    &&
       $kill_object_A->external_db_id == $kill_object_B->external_db_id &&
       $kill_object_A->sequence       eq $kill_object_B->sequence       &&
       $kill_object_A->version        eq $kill_object_B->version ) {

    $identical = 1;
    # the simple stuff is the same, now look deeper
    # done by string comparison like when add_Exon to Transcript

    #
    # check the reasons
    #
    # make a unique string for kill_object_A's reasons
    my $reasonsA = $kill_object_A->get_all_Reasons();
    my @reasonID_listA;
    foreach my $reason (@$reasonsA) {
      push @reasonID_listA, $reason->dbID;
    }
    my @sorted_reasonsA = sort { $a <=> $b } @reasonID_listA;
    my $reasonA_string = join(':', @sorted_reasonsA);

    # make a unique string for kill_object_B's reasons
    my $reasonsB = $kill_object_B->get_all_Reasons();
    my @reasonID_listB;
    foreach my $reason (@$reasonsB) {
      push @reasonID_listB, $reason->dbID;
    }
    my @sorted_reasonsB = sort { $a <=> $b } @reasonID_listB;
    my $reasonB_string = join(':', @sorted_reasonsB);

    # compare the two strings
    if ($reasonA_string ne $reasonB_string) {
      $identical = 0;
      print STDERR "  Reasons are different :  $reasonA_string vs $reasonB_string\n";
    }

    #
    # check the analyses allowed
    #
    # make a unique string for kill_object_A's analyses
    my $analysesA = $kill_object_A->get_all_Analyses_allowed();
    my @analysisID_listA;
    foreach my $analysis (@$analysesA) {
      push @analysisID_listA, $analysis->dbID;
    }
    my @sorted_analysesA = sort { $a <=> $b } @analysisID_listA;
    my $analysisA_string = join(':', @sorted_analysesA);

    # make a unique string for kill_object_B's analyses
    my $analysesB = $kill_object_B->get_all_Analyses_allowed();
    my @analysisID_listB;
    foreach my $analysis (@$analysesB) {
      push @analysisID_listB, $analysis->dbID;
    }
    my @sorted_analysesB = sort { $a <=> $b } @analysisID_listB;
    my $analysisB_string = join(':', @sorted_analysesB);

    # compare the two strings
    if ($analysisA_string ne $analysisB_string) {
      $identical = 0;
      print STDERR "  Analyses_allowed are different :  $analysisA_string vs $analysisB_string\n";
    }

    #
    # check the species_allowed
    #
    # make a unique string for kill_object_A's species
    my $speciesA = $kill_object_A->get_all_Species_allowed();
    my @sppID_listA;
    foreach my $spp (@$speciesA) {
      push @sppID_listA, $spp->dbID;
    }
    my @sorted_speciesA = sort { $a <=> $b } @sppID_listA;
    my $sppA_string = join(':', @sorted_speciesA);

    # make a unique string for kill_object_B's species
    my $speciesB = $kill_object_B->get_all_Species_allowed();
    my @sppID_listB;
    foreach my $spp (@$speciesB) {
      push @sppID_listB, $spp->dbID;
    }
    my @sorted_speciesB = sort { $a <=> $b } @sppID_listB;
    my $sppB_string = join(':', @sorted_speciesB);

    # compare the two strings
    if ($sppA_string ne $sppB_string) {
      $identical = 0;
      print STDERR "  Species_allowed are different :  $sppA_string : $sppB_string\n";
    }
  } else {
    $identical = 0;
    print STDERR "  One of the following is different: external_db_id, taxon, mol_type, accession, version\n";
    print STDERR $kill_object_A->accession." : ".$kill_object_B->accession."\n".
                 $kill_object_A->mol_type." : ".$kill_object_B->mol_type."\n".
                 $kill_object_A->taxon->name." : ".$kill_object_B->taxon->name."\n".
                 $kill_object_A->version." : ".$kill_object_B->version."\n".
                 $kill_object_A->external_db_id." : ".$kill_object_B->external_db_id."\n";
  }
  if ($identical == 1) {
    print STDERR "> Identical\n";
  } else {
    print STDERR "> Not identical\n";
  }
  return $identical;
}
1;
