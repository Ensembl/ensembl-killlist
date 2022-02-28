#!/usr/bin/env perl

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

# # #
# 
# This script is designed to take as input:
# (i) input fasta file
# (ii) name of output fasta file
# (iii) molecule type
#
# The script will remove sequences from the 
# input file and write a new output file 
# without these killed sequences.
#
# # #

use strict;
use warnings;

use Bio::SeqIO;
use Getopt::Long;
use Bio::EnsEMBL::Utils::Exception qw(warning throw);
use Bio::EnsEMBL::KillList::KillList;

$| = 1;

my $infile;
my $outfile;
my $mol_type;

&GetOptions(
            'infile:s'         => \$infile,
            'outfile:s'        => \$outfile,
            'mol_type:s'       => \$mol_type,
           );

if (!defined($infile) || !defined($outfile) || !defined($mol_type) ) {
  throw( "ERROR: Must set infile, outfile and mol_type");
}

# we could allow more than these but these are the ones in the default
# config file
if ($mol_type ne 'PROTEIN' && $mol_type ne 'cDNA') {
  throw("-mol_type must be PROTEIN or cDNA");
}                           

# get all accessions
my $kill_list_object = Bio::EnsEMBL::KillList::KillList->new
                      ( -TYPE => $mol_type,
                       );
my %kill_list = %{ $kill_list_object->get_kill_list() };
foreach my $k (keys %kill_list) { 
  print "$k\n";
}
print STDERR "Have ".scalar(keys %kill_list)." sequences in kill list\n";

# open infile for reading
my $seqin  = new Bio::SeqIO( -file   => "<$infile",
                             -format => "Fasta",
                           );

# open outfile for writing
my $seqout = new Bio::SeqIO( -file   => ">$outfile",
                             -format => "Fasta"
                           );

# loop thru and remove sequences
SEQ: while ( my $seq = $seqin->next_seq ) {
  my $no_version = $seq->id;
  $no_version =~ s/\.\d+//;

  if (exists $kill_list{$no_version}) {
    print STDERR "Removing ".$seq->display_id."\n";
    next SEQ;
  }
  $seqout->write_seq($seq);
}
print STDERR "DONE!\n";
