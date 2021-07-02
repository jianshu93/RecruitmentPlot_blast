#!/usr/bin/perl -w
use strict;
use Getopt::Long;

sub usage {
  print "\nHow to run this code:\n";
  print "./FastA.reformat.oneline.pl -i [input file name] -o [output file name]\n";
  print "This script reformats a fasta file that has the DNA/protein sequence on multiple lines to be all on one line\n";
  print "-i\t\tA fasta file with the sequence broken up on multiple lines\n";
  print "-o\t\tA fasta file with the sequence on one line\n";
  print "Use -h to get this message\n\n";
}

#initializing getopts options
my $input="";
my $output = $input . ".reformatted.fasta";
my $help=0;

sub initialize {
  GetOptions(
    'i=s' => \$input,
    'o=s' => \$output,
    'h'   => \$help,
  ) or die "Incorrect usage!!\n";

  #check for the help message
  if ($help ne 0) { usage(); exit 1;}
  #check for the mandatory input files
  unless (defined $input) {
    print "You need to enter the input file\n"; usage(); exit 1;
  }
}

initialize();

my $header;
my $seq;
my $counter=3;
my @headers;
my @seqs;

open (FILE, "<", $input) or die "Can't open the input file!!!\n";
while (<FILE>) {
  my $line = $_;
  chomp $line;

  #if the line is the first header
  if ($line =~ /^>/ && $counter == 3) {
    $header = $line;
    $counter = 1;
  }

  #if it's the first sequence line
  elsif ($line =~ /[ATGCatgc]/ && $counter==1) {
    $seq = $line;
    $counter = 0;
  }

  #if it's a mid sequence line
  elsif ($line =~ /[ATGCatgc]/ && $counter==0) {
    $seq = $seq . $line;
  }

  #if it's a normal header
  elsif ($line =~ /^>/) {
    #add to the arrays the previous lines
    push @headers, $header;
    push @seqs, $seq;
    $header = $line;
    $counter = 1;
  }

}

close FILE;
#add the last lines
push @headers, $header;
push @seqs, $seq;

open (OUT, ">", $output) or die "Can't open the output file!!!\n";
my $file_length = scalar @headers;
for (my $i=0; $i < $file_length; $i++){
  print OUT $headers[$i], "\n";
  print OUT $seqs[$i], "\n";
}

close OUT;
