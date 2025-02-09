############################### Variable information ##########################################
#Path of workshop
MyWorkshop=/path-to/work_shop

#Path of software
HERAFile=/path-to/HERAFile

#the genome name(less 5 words)
genome_name=gg

#the whole genome assembled sequences with absolute path
genome_seq=/path-to/Test_Genome.fasta

#the corrected pacbio file with absolute path
Corrected_Pacbio=/path-to/Test_CorrectedPacbio.fasta

###############################
### Project information
###############################

#the enzyme used to form the bionano map(if no bionano maps, neglect this parameter)
Enzyme=GCTCTTC

#The software
Working_Script=${HERAFile}/HERA

#the queue used to bsub jobs
queue=workq

#DAZZ_DB
DAZZ_DB=${HERAFile}/DAZZ_DB

#DALIGNER
DALIGNER=${HERAFile}/DALIGNER

#Bwa
Bwa=${HERAFile}/bwa

#the positions apart from start or end
InterIncluded_Side=25000

#internal pacbios and contigs 
InterIncluded_Identity=99;
InterIncluded_Coverage=99;

#the pacbios selected for starting and ending
MinIdentity=98
MinCoverage=90
MinLength=5000

#the conditions used to filter the overlap used to construct the graph
MinIdentity_Overlap=97
MinOverlap_Overlap=1000
MaxOverhang_Overlap=100
MinExtend_Overlap=1000

#the min num path for contig pairs
MinPathNum=5

#the conditons used to merge the supercontigs and non-scaffolded contigs
MinIdentity_Merge=98
MinOverlap_Merge=10000
MaxOverhang_Merge=200

#the scaffold formed by bionano maps
Bionano_Scaffolded_Contig=${MyWorkshop}/Large_Contig.fasta

#the non-scaffold contigs
Bionano_NonScaffolded_Contig=${MyWorkshop}/Small_Contig.fasta

############################### end of resetting parameters ##################################################
#Make the working dirs
mkdir 01-Pacbio_And_NonScaffold
cd 01-Pacbio_And_NonScaffold
$Working_Script/Check
cd -
mkdir 02-Pacbio-Alignment
cd 02-Pacbio-Alignment
$Working_Script/Check
cd -
mkdir 03-Pacbio-SelfAlignment
cd 03-Pacbio-SelfAlignment
$Working_Script/Check
cd -
mkdir 04-Graphing
cd 04-Graphing
$Working_Script/Check
cd -
mkdir 05-PathContig
cd 05-PathContig
$Working_Script/Check
cd -
mkdir 06-Daligner
cd 06-Daligner
$Working_Script/Check
cd -
mkdir 07-FilledGap
cd 07-FilledGap
$Working_Script/Check
cd -
mkdir 08-PathContig_Consensus
mkdir 09-ReAssembly
$Working_Script/Check

#convert the fasta to lines
$Working_Script/readstoline $genome_seq $genome_name-Genome.fasta C

#split the sequences into two files with large contigs and small contigs
$Working_Script/01-Filter_Raw_Contig_By_Length $genome_name-Genome.fasta Large_Contig.fasta Small_Contig.fasta 50000 15000

#covert the fasta formate to lines
$Working_Script/readstoline $Corrected_Pacbio $genome_name-CorrectedPacbio.fasta P

Corrected_Pacbio=$genome_name-CorrectedPacbio.fasta

#Merge the non-scaffolded contig with corrected pacbio and they are all used to construct overlaping graph
cat $Bionano_NonScaffolded_Contig $Corrected_Pacbio >Query_Merged.fasta

#Change the dir of working 
cd ${MyWorkshop}/01-Pacbio_And_NonScaffold

#Split the corrected pacbios and non-scaffolded contigs into parts
$Working_Script/03-fasta-splitter --n-parts 100 ../Query_Merged.fasta

#Make the list of split sequence
cd -
ls ${MyWorkshop}/01-Pacbio_And_NonScaffold/*.fasta >list_Split.txt

#Make the index of Contig 
${Bwa}/bwa index $Bionano_Scaffolded_Contig

#Align the corrected pacbios and non-scaffolded contigs to scaffolded contigs
perl $Working_Script/04-PBS-Qsub-Mapping2Ctg.pl ${MyWorkshop}/list_Split.txt $Bionano_Scaffolded_Contig \
    ${MyWorkshop}/02-Pacbio-Alignment $Working_Script $queue $genome_name ${Bwa}>log

#Wait until the end of all alignment
job=`qstat |awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-Map" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;

echo ${job};
sleep 20;

while (($job>=1))
        do job=`qstat |awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-Map" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;\
		echo $job;sleep 20;
done

#Remove the log and pbs files
rm -f *.log
rm -f *.err
rm -f [0-9]*.pbs

# Checkpoint
echo Finish QSUB1 at `date`   ...OK
sleep 10;

#Merge all alignment into an single file
cat ${MyWorkshop}/02-Pacbio-Alignment/Part_Alignment_*.txt > ${MyWorkshop}/02-Pacbio-Alignment/Total_Alignment.txt
#rm -f ${MyWorkshop}/02-Pacbio-Alignment/Part_Alignment_*.txt


#Remove the pacbios and non-scaffolded contigs aligned to the internal scaffolded contigs 
$Working_Script/05-Filtered_InterIncluded_Pacbio ${MyWorkshop}/02-Pacbio-Alignment/Total_Alignment.txt \
    ${MyWorkshop}/02-Pacbio-Alignment/InterIncluded_Pacbio.txt $InterIncluded_Identity $InterIncluded_Coverage $InterIncluded_Side


#Record the pacbio alignment of contig's head and end
$Working_Script/06-Extract_Contig_Head_Tail_Pacbio_Alignment -Align=${MyWorkshop}/02-Pacbio-Alignment/Total_Alignment.txt \
    -MinIden=$MinIdentity -MinCov=$MinCoverage -HTLen=$InterIncluded_Side -MinLen=$MinLength

#Change the aligned positions into positive chain
$Working_Script/10-Switch_Locus_To_Positive Contig_Head_Tail_Pacbio.txt ${MyWorkshop}/04-Graphing/Contig_Head_Tail_Pacbio_Pos.txt

#Extract the sequence of corrected pacbio and non-scaffoled contigs which are nonaligned or aligned to the start or end of the contigs
$Working_Script/07-extract_fasta_seq_by_name ${MyWorkshop}/02-Pacbio-Alignment/InterIncluded_Pacbio.txt ${MyWorkshop}/Query_Merged.fasta \
    ${MyWorkshop}/02-Pacbio-Alignment/Both_Side_Pacbio.fasta

#Split the remained pacbio or contigs into parts
cd ${MyWorkshop}/03-Pacbio-SelfAlignment
$Working_Script/03-fasta-splitter --n-parts 30 ${MyWorkshop}/02-Pacbio-Alignment/Both_Side_Pacbio.fasta

#Make index for every part of the pacbios and non-scaffolded contigs
cd -
ls ${MyWorkshop}/03-Pacbio-SelfAlignment/*.fasta >${MyWorkshop}/list_outer_pacbio.txt

perl $Working_Script/08-PBS-Qsub_job_index.pl ${MyWorkshop}/list_outer_pacbio.txt $queue $genome_name ${Bwa} >>log

#Wait until the end of making all index
job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-INDEX" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`

echo ${job};
sleep 20;

while (($job>=1))
       do job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-INDEX" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;\
	   echo $job;sleep 20;
done

rm -f *.log
rm -f *.err
rm -f [0-9]*.pbs

# Checkpoint
echo Finish QSUB2 at `date`   ...OK 
sleep 10;

##############################################

#Align the corrected pacbios and non-scaffolded contigs to each other for finding overlaps
perl $Working_Script/09-PBS-Qsub-Pair_Alignment.pl ${MyWorkshop}/list_outer_pacbio.txt $Working_Script $queue $genome_name ${MyWorkshop} ${Bwa}>>log

#Wait until the end of making all index
job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-Pair" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`

echo ${job};
sleep 20;

while (($job>=1))
       do job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-Pair" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;\
	   echo $job;sleep 20;
done

rm -f *.log
rm -f *.err
rm -f [0-9]*.pbs

# Checkpoint
echo Finish QSUB3 at `date`   ...OK 

##############################################

#Merge all alignment into an single file
cat ${MyWorkshop}/03-Pacbio-SelfAlignment/Part_SelfAlignment_*.txt > ${MyWorkshop}/03-Pacbio-SelfAlignment/Total_SelfAlignment.txt

#Filter the alignment for overlaping

$Working_Script/11-PacbioAlignmentFilter ${MyWorkshop}/03-Pacbio-SelfAlignment/Total_SelfAlignment.txt \
    $MaxOverhang_Overlap $MinIdentity_Overlap $MinOverlap_Overlap $MinExtend_Overlap > ${MyWorkshop}/04-Graphing/PacbioAlignmentFiltered.txt

#Find the proper overlap for constructing the graph
$Working_Script/12-PacbioAlignmentLinker ${MyWorkshop}/04-Graphing/PacbioAlignmentFiltered.txt \
    $MaxOverhang_Overlap $MinExtend_Overlap > ${MyWorkshop}/04-Graphing/PacbioAlignmentLinked.txt

#Constrct graph by the alignment of pacbios, and the nodes are pacbios and the edges are overlaps. 
#Then Finding Contigs Pathway with the Correct Orientatios

cd ${MyWorkshop}/04-Graphing/

$Working_Script/Selected_Best_Pairs PacbioAlignmentLinked.txt PacbioAlignmentLinked_BestMatch.txt
$Working_Script/13-Graph_By_Finding_Best_MaxExtending_Random_Path PacbioAlignmentLinked_BestMatch.txt >check

#Output the uniq path
cat ctg_clusters.txt |sort |uniq > ${MyWorkshop}/05-PathContig/ctg_clusters_uniq.txt
cat cluster_ori.txt |sort |uniq > ${MyWorkshop}/05-PathContig/cluster_ori_uniq.txt

cd -


cd ${MyWorkshop}/05-PathContig
#Make the corrected pacbios and non-scaffolded contigs into a line
$Working_Script/14-make_ctg_line ${MyWorkshop}/05-PathContig/cluster_ori_uniq.txt cluster_ori_same_chain.txt

$Working_Script/18-compute_fasta_file_len ${MyWorkshop}/Query_Merged.fasta Query_Len.txt

#Change the path into the same chain of bionano scaffolds
$Working_Script/15-make_junction_by_pos ${MyWorkshop}/04-Graphing/ctg_pairs.txt Query_Len.txt cluster_ori_same_chain.txt cluster_ori_same_chain_pos.txt

#Extract the aligned information of pacbios for final pathcontigs
$Working_Script/16-extract_ctg_infor_for_seq cluster_ori_same_chain_pos.txt cluster_ori_same_chain_pos_for_seq.txt
echo ">NA" >NA.fasta
echo "ATCG" >>NA.fasta

#Output the final contigs of path used to fill the gap of bionano
$Working_Script/17-extract_seq_by_pos cluster_ori_same_chain_pos_for_seq.txt ${MyWorkshop}/Query_Merged.fasta NA.fasta PathContig.fasta

#Compute the length of pathcontigs
$Working_Script/18-compute_fasta_file_len PathContig.fasta ${MyWorkshop}/06-Daligner/PathContig_Len.txt

##########
cd -

#make the working dirs
mkdir 10-Contig_Pairs
cd ${MyWorkshop}/10-Contig_Pairs
$Working_Script/Check
touch overlap.txt

#formating the contig pairs based on the paths
$Working_Script/03-Formate_Contig_Pairs_By_Paths overlap.txt ${MyWorkshop}/05-PathContig/ctg_clusters_uniq.txt Contig_Pairs.txt

cat Contig_Pairs.txt |awk '{if(($5+$6/3+$7/6)>='$MinPathNum'){$8=$5+$6/3+$7/6;print $0;}}' >Contig_Pairs_Filtered.txt

#selecting the final contig pairs with clustering based on scores
$Working_Script/05-Merge_With_HighestScore_To_Sequence_By_Path Contig_Pairs_Filtered.txt ../Large_Contig.fasta SuperContig.fasta >Selected_Pairs.txt

cd -

cd ${MyWorkshop}/06-Daligner

#extract the paths which connects the final selected contigs
$Working_Script/19-Path2Scaffold_NoBioNano ${MyWorkshop}/10-Contig_Pairs/Selected_Pairs.txt \
    ${MyWorkshop}/05-PathContig/ctg_clusters_uniq.txt PathContig_Len.txt Path_Scaffold.txt

#rename the path contigs
$Working_Script/20-PathContig-Rename_NoBioNano Path_Scaffold.txt ${MyWorkshop}/05-PathContig/PathContig.fasta PathContig_Rename.fasta >log

$Working_Script/Rename1 ${MyWorkshop}/10-Contig_Pairs/SuperContig.fasta  SuperContig_Rename.fasta >Rename_Pairs.txt
$Working_Script/Rename2 Rename_Pairs.txt PathContig_Rename.fasta PathContig_Rename2.fasta
mv -f PathContig_Rename2.fasta PathContig_Rename.fasta

#formating the connected scaffold
$Working_Script/01-Gap_Count SuperContig_Rename.fasta $Enzyme Gap.txt
$Working_Script/01-Finding_Contigs_Gap Gap.txt Scaffold2Ctg_Gap.txt
$Working_Script/02-Split_Scaffold_To_Contigs SuperContig_Rename.fasta Prosudo_ScaffoldNonEnzyme2Contig.fasta $Enzyme

#aligning the path-contigs to scaffold
perl $Working_Script/21-PBS-Daligner_New.pl ${MyWorkshop}/06-Daligner/Scaffold2Ctg_Gap.txt  \
    ${MyWorkshop}/06-Daligner/Prosudo_ScaffoldNonEnzyme2Contig.fasta \
    ${MyWorkshop}/06-Daligner/PathContig_Rename.fasta $queue $Working_Script $genome_name $DAZZ_DB $DALIGNER ${MyWorkshop}

#Wait until the end of all alignment
job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-DALIGNER" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;

echo ${job}
sleep 20;

while (($job>=1))
        do job=`qstat|awk '{if($6=="'$queue'") print $2;}'| grep "$genome_name-DALIGNER" |awk 'BEGIN{count=0}{count=count+1;}END{print count;}'`;\
		echo $job;sleep 20;
done

#Remove the log and pbs files
rm -f *.log
rm -f *.err
rm -f [0-9]*.pbs

# Checkpoint
echo Finish QSUB4 at `date`   ...OK 
sleep 10;

#filling the gaps with the path-contigs and the final sequence of Supercontig is SuperContig.fasta
$Working_Script/22-Filling-Gap Scaffold2Ctg_Gap.txt Prosudo_ScaffoldNonEnzyme2Contig.fasta PathContig_Rename.fasta SuperContig.fasta

#formating the final genome
#warnings: In general, users need to filter the used small contigs in "Small_Contig.fasta" rather than simply merge files. 
#Users can map the small contigs to SuperContigs by the tools of bwa and filter the small contigs by coverage.
cat SuperContig.fasta $Bionano_NonScaffolded_Contig |awk 'BEGIN{count=1;}{if($0~/^>/){print ">SuperContig"count"END";count++;}else{print $0;}}' >../$genome_name-Final_Genome_HERA.fasta

cd ${MyWorkshop}
~/biosoft/quast-5.0.2/quast.py -t 20 -o quast_out $genome_name-Final_Genome_HERA.fasta

