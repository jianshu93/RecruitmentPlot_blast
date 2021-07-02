## This is wrapper for recuitment plot based on blast
You mush have R and Perl installed on your machine. By default perl is installed on Linux and MacOS. You need to install R for plotting. I want to thank Genevie for the first version. Please contact me jianshuzhao@yahoo.com



You can create as many plots as you want parallelly. The blast step take some time. For a metagenomes with 3.0 GB (forwared reads only, unzipped) and 14 reference genomes. It take 2 hours.

blast+ and seqtk must be installed for alignment. If you are using conda, run conda install -c bioconda blast seqtk

Only Interleaved (people also call it merge in bbtools software) reads are supported for now. I will add support for forward and reverse reads.

If you have paired read, use the seqtk software to intleave your reads:

```
conda install seqtk -c bioconda
seqtk mergepe R1.fasta.gz R2.fasta.gz > interleaved.fasta
```

### Running
```
## on Linux
git clone https://github.com/jianshu93/RecruitmentPlot_blast
cd RecruitmentPlot_blast
### get enveomics package (enveomics folder must be in the RecruitmentPlot_blast directory )
git clone https://github.com/lmrodriguezr/enveomics
wget http://rothlab.com/Data/T4AerOil_sbsmpl5.fa.gz
mv T4AerOil_sbsmpl5.fa.gz ./demo_input
gunzip ./demo_input/T4AerOil_sbsmpl5.fa.gz
./makeRecruitmentPlot_linux.sh ./demo_input/MAG ./demo_input/T4AerOil_sbsmpl5.fa try

## on MacOS, install homebrew first
brew install grep
git clone https://github.com/jianshu93/RecruitmentPlot_blast
cd RecruitmentPlot_blast
### get enveomics package
git clone https://github.com/lmrodriguezr/enveomics
wget http://rothlab.com/Data/T4AerOil_sbsmpl5.fa.gz
mv T4AerOil_sbsmpl5.fa.gz ./demo_input
gunzip ./demo_input/T4AerOil_sbsmpl5.fa.gz
./makeRecruitmentPlot.sh ./demo_input/MAG ./demo_input/T4AerOil_sbsmpl5.fa try

```

### See an example for the demo dataset
lab5_MAG_001 recruitment plot
![lab5_MAG 001 recruitment](https://user-images.githubusercontent.com/38149286/124207245-13bbad80-dab3-11eb-84be-ca02ae623a16.jpg)

### Reference

Rodriguez-R, Luis M. and Konstantinos T. Konstantinidis. 2016. “The Enveomics Collection: a Toolbox for Specialized Analyses of Microbial Genomes and Metagenomes.” PeerJ 1–16.