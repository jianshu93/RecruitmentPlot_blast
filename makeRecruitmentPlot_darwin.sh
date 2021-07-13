#!/bin/bash

#checks for usage
if [[ "$1" == "" || "$1" == "-h" || "$2" == "" || "$3" == "" ]]
then
  echo "
  Usage: ./makeRecruitmentPlot.sh database_dir query.fa output_base

  database_dir      directory that contains fasta files (must ends with .fasta) which will be the database [most likely your longer sequence]
  query.fa      Fasta file that will be mapped to the database [most likely your reads]
  output_base   Base name for the blast output and recruitment plots
                blast output:         output_base.blst [Unique matches with over 70% coverage and 50 bp match]
                recruitment object:   output_base.recruitment.out
                recruitment pdf:      output_base.recruitment.pdf
  " >&2
  exit 1
fi

#stores file names
database=$1
reads=$2
output=$3

if ! command -v blastn &> /dev/null
then
    echo "blastn could not be found, please install it via conda or from source"
    exit
fi
if ! command -v seqtk &> /dev/null
then
    echo "seqtk could not be found, please install it via conda or from source"
    exit
fi

if [ -d "$database" ]; then
    echo "$database exists"
    dfiles="${database}/*.fasta"
    for F in $dfiles; do
	      BASE=${F##*/}
	      SAMPLE=${BASE%.*}
        $(./dependencies/seqtk_darwin rename $F ${SAMPLE}. > ./${SAMPLE}.all.fasta)
        $(./dependencies/seqtk_darwin seq -C ./${SAMPLE}.all.fasta > ./${SAMPLE}.fasta)
        $(rm ./${SAMPLE}.all.fasta)
        $(cat ./${SAMPLE}.fasta >> ./all_mags_rename.fa)
    done
else
    echo "input directory does not exist, please offer a directory that exists (must ends with fasta files)"
    exit 1
fi

database_all=./all_mags_rename.fa
#variables
enveomics="./enveomics"
BLAST=0

#Reformat fastas
if [[ -s all_mags_rename.reformatted ]]
then
  database_all=all_mags_rename.reformatted
else
  #check if file needs it
  num_lines=$(wc -l all_mags_rename.fa | head -n1 | awk '{print $1;}')
  num_headers=$(grep ">" all_mags_rename.fa | wc -l)
  num_headers=$((num_headers * 2))
  if [[ $num_headers -eq $num_lines ]]
  then
    echo "The $database genome file is in correct format..."
  else
    #reformat the fasta and rename the variable
    echo "Reformatting the $database file so seqs are on one line..."
    ./FastA.reformat.oneline.pl -i all_mags_rename.fa -o all_mags_rename.reformatted
    echo "Done reformatting $database..."
    database_all=all_mags_rename.reformatted
  fi
fi

if [[ -s $reads.reformatted ]]
then
  reads=$reads.reformatted
else
  #Check reformatting the other file
  num_lines=$(wc -l $reads | head -n1 | awk '{print $1;}')
  num_headers=$(grep ">" $reads | wc -l)
  num_headers=$((num_headers * 2))
  if [[ $num_headers -eq $num_lines ]]
  then
    echo "The $reads file is in correct format..."
  else
    #reformat the fasta and rename the variable
    echo "Reformatting the $reads file so seqs are on one line..."
    ./FastA.reformat.oneline.pl -i $reads -o $reads.reformatted
    echo "Done reformatting $reads..."
    reads=$reads.reformatted
  fi
fi

#Check to see if the final blast file is present
if [[ -s $output.blst ]]
then
  echo "Final blast file found. Not running blast again or filtering..."
  echo "Now running recruitment plot scripts..."
  BLAST=1
else
  #Run blast
  echo "Making BLAST database..."
  makeblastdb -in $database_all -dbtype nucl

  echo "Running BLAST with 70% identity cutoff..."
  blastn -db $database_all -query $reads -outfmt 6 -out $output.tmp.orig.blst -perc_identity 70
  echo "Done with BLAST..."
  #Filter for length
  echo "Adding length of query to blast result and filtering for 90% match"
  ./BlastTab.addlen.pl -i $reads -b $output.tmp.orig.blst -o $output.tmp.length.blst
  #Filter for best match
  echo "Only keeping best match from BLAST results..."
  ./BlastTab.besthit.pl -b $output.tmp.length.blst -o $output.blst
fi

### install dependencies
echo "Install R packages for recruitment plot"
Rscript -e "install.packages('enveomics.R', repos = 'http://cran.rstudio.com/', quiet = TRUE)"
Rscript -e "install.packages('optparse', repos = 'http://cran.rstudio.com/', quiet = TRUE)"

#extract blast for each genome and build recruitment plot
dfiles=./*.fasta
for F in $dfiles; do
	BASE=${F##*/}
	SAMPLE=${BASE%.*}
  $(ggrep -E "*$SAMPLE.*" $output.blst > ./$SAMPLE.blst)
  $enveomics/Scripts/BlastTab.catsbj.pl ./$SAMPLE.fasta ./$SAMPLE.blst 
  Rscript $enveomics/Scripts/BlastTab.recplot2.R --threads 8 --prefix ./$SAMPLE.blst ./$SAMPLE.recruitment.Rdata ./$SAMPLE.recruitment.pdf
  rm ./$SAMPLE.blst.lim
  rm ./$SAMPLE.blst.rec
  echo "
    Plot for $SAMPLE.fasta is finished. Output files:
    $SAMPLE.blst
    $SAMPLE.recruitment.Rdata
    $SAMPLE.recruitment.pdf"
done
#print statistics
if [[ $BLAST -eq 0 ]]
then
  num_orig=$(wc -l $output.tmp.orig.blst | head -n1 | awk '{print $1;}')
  num_length=$(wc -l $output.tmp.length.blst | head -n1 | awk '{print $1;}')
  num_best=$(wc -l $output.blst | head -n1 | awk '{print $1;}')
  echo "
      Original number of blast hits:                            $num_orig
      Number of blast hits after filter for length of match:    $num_length
      Number of blast hits after filter for best match:         $num_best"

  #remove temporary files
  rm $output.tmp.orig.blst
  rm $output.tmp.length.blst
else
  num_best=$(wc -l $output.blst | head -n1 | awk '{print $1;}')
  echo "
    Number of blast hits:         $num_best"
fi
echo "All done"
