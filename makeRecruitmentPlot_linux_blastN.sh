#!/bin/bash


#checks for usage
if [[ "$1" == "" || "$1" == "-h" || "$2" == "" || "$3" == "" ]]
then
  echo "
  Usage: ./makeRecruitmentPlot.sh database_dir query.fa output_dir

  database_dir      directory that contains genome fasta files (must ends with .fasta) which will be the database [most likely your longer sequence]
  query.fa      Fasta file that will be mapped to the database [most likely your reads, interleaved reads in fasta format is expected]
  output_dir    directory for the blast output and recruitment plots
                blast output:         final.blst [Unique matches with over 70% coverage and 50 bp match]
                recruitment object:   genome_name.recruitment.out
                recruitment pdf:      genome_name.recruitment.pdf
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

if [ -d "$output" ] 
then
    echo "Directory $output already exists. MAKE SURE you want to do this"
else
    echo "making directory $output ..."
    $(mkdir $output)
fi

if [ -d "$database" ]; then
    echo "$database exists"
    dfiles="${database}/*.fasta"
    for F in $dfiles; do
	      BASE=${F##*/}
	      SAMPLE=${BASE%.*}
        $(./dependencies/seqtk_linux rename $F ${SAMPLE}. > $output/${SAMPLE}.all.fasta)
        $(./dependencies/seqtk_linux seq -C $output/${SAMPLE}.all.fasta > $output/${SAMPLE}.fasta)
        $(rm $output/${SAMPLE}.all.fasta)
        $(cat $output/${SAMPLE}.fasta >> $output/all_mags_rename.fa)
    done
else
    echo "input directory does not exist, please offer a directory that exists (must ends with fasta files)"
    exit 1
fi

database_all=$output/all_mags_rename.fa
#variables
enveomics="./enveomics"
BLAST=0


#Reformat fastas
if [[ -s $output/all_mags_rename.reformatted ]]
then
  database_all=$output/all_mags_rename.reformatted
else
  #check if file needs it
  num_lines=$(wc -l $output/all_mags_rename.fa | head -n1 | awk '{print $1;}')
  num_headers=$(grep ">" $output/all_mags_rename.fa | wc -l)
  num_headers=$((num_headers * 2))
  if [[ $num_headers -eq $num_lines ]]
  then
    echo "The $database genome file is in correct format..."
  else
    #reformat the fasta and rename the variable
    echo "Reformatting the $database file so seqs are on one line..."
    ./FastA.reformat.oneline.pl -i $output/all_mags_rename.fa -o $output/all_mags_rename.reformatted
    echo "Done reformatting $database..."
    database_all=$output/all_mags_rename.reformatted
  fi
fi

if [[ -s $output/$reads.reformatted ]]
then
  reads=$output/$reads.reformatted
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
    ./FastA.reformat.oneline.pl -i $reads -o $output/$reads.reformatted
    echo "Done reformatting $reads..."
    reads=$output/$reads.reformatted
  fi
fi

#Check to see if the final blast file is present
if [[ -s $output/final.blst ]]
then
  echo "Final blast file found in the output directory you provided. Not running blast again or filtering..."
  echo "Now running recruitment plot scripts..."
  BLAST=1
else
  #Run blast
  echo "Making BLAST database..."
  makeblastdb -in $database_all -dbtype nucl
  echo "Running BLAST with 70% identity cutoff..."
  blastn -db $database_all -query $reads -out $output/tmp.orig.blst -task blastn -mt_mode 1 -num_threads $(nproc) -evalue 1e-9 -outfmt '6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen'
  echo "Done with BLAST..."
  #Filter for length
  echo "Adding length of query to blast result and filtering for 90% match"
  ./BlastTab.addlen.pl -i $reads -b $output/tmp.orig.blst -o $output/tmp.length.blst
  #Filter for best match
  echo "Only keeping best match from BLAST results..."
  ./BlastTab.besthit.pl -b $output/tmp.length.blst -o $output/final.blst
fi

### install dependencies
echo "Install R packages for recruitment plot"
Rscript -e "install.packages('enveomics.R', repos = 'http://cran.rstudio.com/', quiet = TRUE)"
Rscript -e "install.packages('optparse', repos = 'http://cran.rstudio.com/', quiet = TRUE)"

#extract blast for each genome and build recruitment plot
dfiles=$output/*.fasta
for F in $dfiles; do
	BASE=${F##*/}
	SAMPLE=${BASE%.*}
    $(grep -E "*${SAMPLE}.*" $output/final.blst > $output/$SAMPLE.blst)
    $enveomics/Scripts/BlastTab.catsbj.pl $output/$SAMPLE.fasta $output/$SAMPLE.blst 
    Rscript $enveomics/Scripts/BlastTab.recplot2.R --threads 24 --prefix $output/$SAMPLE.blst $output/$SAMPLE.recruitment.Rdata $output/$SAMPLE.recruitment.pdf
    rm $output/$SAMPLE.blst.lim
    rm $output/$SAMPLE.blst.rec
    echo "
    Plot is finished. Output files:
    $output/$SAMPLE.blst
    $output/$SAMPLE.recruitment.Rdata
    $output/$SAMPLE.recruitment.pdf"
done
#print statistics
if [[ $BLAST -eq 0 ]]
then
  num_orig=$(wc -l $output/tmp.orig.blst | head -n1 | awk '{print $1;}')
  num_length=$(wc -l $output/tmp.length.blst | head -n1 | awk '{print $1;}')
  num_best=$(wc -l $output/final.blst | head -n1 | awk '{print $1;}')
  echo "
      Original number of blast hits:                            $num_orig
      Number of blast hits after filter for length of match:    $num_length
      Number of blast hits after filter for best match:         $num_best"

  #remove temporary files
  rm $output/tmp.orig.blst
  rm $output/tmp.length.blst
else
  num_best=$(wc -l $output/final.blst | head -n1 | awk '{print $1;}')
  echo "
    Number of blast hits:         $num_best"
fi
echo "All done"
