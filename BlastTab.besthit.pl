#!/usr/bin/perl -w
use strict;
use Getopt::Long;

#getopts files
my $blast_file;
my $help=0;
my $output;

#global variables
my %hits;
my $duplicate_count=0;
my $total_count=0;
my $unique_count=0;

sub initialize {
  GetOptions(
  'b=s' => \$blast_file,
  'o=s' => \$output,
  'h' => \$help,
  ) or die "Incorrect usage!\n";

  #check for help
  if ($help ne 0) {usage(); exit 1;}
  unless (defined $blast_file) {
    print "You must enter all files\n"; usage(); exit 1;
  }
  unless (defined $output) {
    $output="$blast_file.bestmatch";
  }
}

sub usage {
  print "\nHow to run this code:\n";
  print "\n./BlastTab.besthit.pl -b blast_file -o output_name\n";
  print "The blast must be in tabular blast format\n";
  print "The output will be in tabular blast format with only the best hit for each query sequence\n";
}

sub findDuplicates {
  my ($blast) = @_;
  open (BLAST, "<", $blast) or die "Can't open the file $blast!!\n";
  my $line; my @values;
  my $query; my $old_bitscore; my $new_bitscore;
  while (<BLAST>) {
    $line = $_;
    chomp $line;
    @values = split('\t', $line);
    $query = $values[0];

    if (defined $hits{$query}) {
      $duplicate_count++;
      ($old_bitscore) = (split('\t', $hits{$query}))[11];
      #print "The old bitscore value: $old_bitscore\n";
      $new_bitscore = $values[11];
      #print "The new bitscore value: $new_bitscore\n";

      if ($new_bitscore > $old_bitscore) {
        #print "Getting new line\n";
        $hits{$query} = $line;
      }
      else {
        #print "Keeping old\n";
      }
    }
    else{
      $hits{$query} = $line;
      $unique_count++;
    }
    $total_count++;
  }
  close BLAST;
}

initialize();
findDuplicates($blast_file);
open (OUT, ">", $output) or die "Can't open the output file!!\n";
for my $keys (keys %hits) {
  print OUT $hits{$keys}, "\n";
}
close OUT;
print "Number of total entries:       $total_count\n";
print "Number of unique entries:      $unique_count\n";
print "Number of duplicates removed:  $duplicate_count\n";
