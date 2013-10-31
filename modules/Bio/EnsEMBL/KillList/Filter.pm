
package Bio::EnsEMBL::KillList::Filter;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning stack_trace_dump );
use Bio::EnsEMBL::Utils::Argument qw(rearrange);


sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my ($reasons, $for_analyses, $for_species,
      $only_mol_type, $for_external_db_ids, $before_date,
      $user, $from_source_species, $having_status) = 
      rearrange(['REASONS', 'FOR_ANALYSES', 'FOR_SPECIES',
                 'ONLY_MOL_TYPE', 'FOR_EXTERNAL_DB_IDS', 'BEFORE_DATE', 
                 'USER', 'FROM_SOURCE_SPECIES', 'HAVING_STATUS'],@_);

  my $self = bless({}, $class);

  if ($reasons) {
    $self->{'_reason_array'} = $reasons;
  } else {
    $self->{'_reason_array'} = [];
  }

  if ($for_analyses) {
    $self->{'_analysis_array'} = $for_analyses;
  } else {
    $self->{'_analysis_array'} = [];
  }

  if ($for_species) {
    $self->{'_for_species_array'} = $for_species;
  } else {
    $self->{'_for_species_array'} = [];
  }

  if ($for_external_db_ids) {
    $self->{'_external_db_id_array'} = $for_external_db_ids;
  } else {
    $self->{'_external_db_id_array'} = [];
  }

  #if(defined $user && (!ref($user) || !$user->isa('Bio::EnsEMBL::KillList::User'))) {
  #  throw('-USER argument must be a Bio::EnsEMBL::User not '.
  #        $user);
  #}
  $self->user( $user ) if ( defined $user );

  if(defined $from_source_species && (!ref($from_source_species) || !$from_source_species->isa('Bio::EnsEMBL::KillList::Species'))) {
    throw('-SOURCE_SPECIES argument must be a Bio::EnsEMBL::Species not '.
          $from_source_species);
  }
  $self->source_species( $from_source_species ) if ( defined $from_source_species );
  $self->status( $having_status ) if ( defined $having_status );
  $self->mol_type( $only_mol_type ) if ( defined $only_mol_type );

  if (defined $before_date) {
    my $datetime = _format_date_string($before_date);
    $self->timestamp($datetime);
  } 

  return $self;
}

sub add_Species_allowed {
  my ($self,$for_species) = @_;

  unless(defined $for_species && ref $for_species
         && $for_species->isa("Bio::EnsEMBL::KillList::Species") ) {
    throw("[$for_species is not a Bio::EnsEMBL::KillList::Species!");
  }

  $self->{'_for_species_array'} ||= [];
  push (@{$self->{'_for_species_array'}}, $for_species);
}

sub get_all_Species_allowed {
  my ($self) = @_;
  if (!defined $self->{'_for_species_array'} && defined $self->adaptor()) {
    $self->{'_for_species_array'} = $self->adaptor()->db()->get_SpeciesAdaptor()->fetch_all_by_KillObject($self);
  }
  if (!defined $self->{'_for_species_array'} && defined $self->adaptor()) {
    $self->{'_for_species_array'} = $self->adaptor()->db()->get_SpeciesAdaptor()->fetch_all_by_dbID($self);
  }
  return $self->{'_for_species_array'};
}

sub flush_Species_allowed {
  my ($self,@args) = @_;
  $self->{'_for_species_array'} = [];
}

sub add_Reason {
  my ($self,$reason) = @_;

  unless(defined $reason && ref $reason
         && $reason->isa("Bio::EnsEMBL::KillList::Reason")) {
    throw("Reason [$reason] not a " .
            "Bio::EnsEMBL::KillList::Reason");
  }

  $self->{'_reason_array'} ||= [];
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
          "Bio::EnsEMBL::KillList::Analysis");
  }

  $self->{'_analysis_array'} ||= [];
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

sub add_external_db_id {
  my ($self,$external_db_id) = @_;

  unless(defined $external_db_id) {
    throw("No external_db_id given");
  }

  $self->{'_external_db_id_array'} ||= [];
  push @{$self->{'_external_db_id_array'}}, $external_db_id;

}

sub get_all_external_db_ids {
  my ($self) = @_;
  $self->{'_external_db_id_array'} ||= [];
  return $self->{'_external_db_id_array'};
}

sub flush_external_db_ids {
  my ($self,@args) = @_;
  $self->{'_external_db_id_array'} = [];
}

sub user {
  my $self = shift;
  $self->{'user'} = shift if ( @_ );
  return $self->{'user'};
}

sub source_species {
  my $self = shift;
  $self->{'source_species'} = shift if ( @_ );
  return $self->{'source_species'};
} 

sub status {
  my $self = shift;
  $self->{'status'} = shift if ( @_ );
  return $self->{'status'};
}

sub mol_type {
  my $self = shift;
  $self->{'mol_type'} = shift if ( @_ );
  return $self->{'mol_type'};
}

sub timestamp {
  my $self = shift;
  $self->{'timestamp'} = shift if ( @_ );
  return $self->{'timestamp'};
}

sub _format_date_string {
  my ($date) = @_;

  if ($date !~ m/\d\d\d\d\D\d\d\D\d\d/) {
    throw ("Date ($date) in incorrect format. Please supply in format YYYY-MM-DD");
  }
  $date =~ s/\D+/-/g;
  $date .= ' 00:00:00';
  return $date;
}


sub _clone_Filter {
  throw ("method does not yet exist");
}

1;



