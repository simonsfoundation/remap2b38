#!/bin/bash

export PATH=/mnt/xfs1/home/asalomatov/projects/dnanexus/bin/:/mnt/xfs1/home/asalomatov/projects/dnanexus/anaconda/jre/bin/:$PATH

prefix=$1
indir=$2
echo "$(date) : timing for $prefix start of computation on $(hostname)"

working_dir=$3
output_dir=$4
rm_work_dir=$5
mkdir -p $output_dir
nCores=$6
inclmk=~/projects/pipeline/ppln/include_hg38.mk
#b37_genome=/mnt/xfs1/bioinfoCentos7/data/bcbio_nextgen/150617/genomes/Hsapiens/GRCh37/seq/GRCh37.fa
#cd /mnt/ceph/users/asalomatov/regeneron_spark_pilot/resources
#b38_genome=hg38/genome.fa
#GATK=/mnt/xfs1/bioinfoCentos7/software/installs/GATK/3.6/GenomeAnalysisTK.jar
#MILLS=/mnt/ceph/users/asalomatov/regeneron_spark_pilot/resources/gatk/Mills_and_1000G_gold_standard.indels.b38.vcf.gz

echo "all arguments $@"
echo "Running $prefix on $(hostname) in $workdir using $nCores cores."

if [ "$working_dir" = "tmp" -o "$working_dir" = "TMP" ]
then
    workdir=$(mktemp -d /tmp/working_XXXXXXXXXX)
elif [ "$working_dir" = "scr" -o "$working_dir" = "SCR" ]
then
    workdir=$(mktemp -d /scratch/working_XXXXXXXXXX)
else
    workdir=${output_dir}/work
    mkdir -p $workdir
fi
echo "work dir is $workdir"

function cleanup {
    echo "Should you run 'rm -rf $workdir' on $(hostname)?"
    if [ $rm_work_dir -eq 1 ]; then
        echo "running 'rm -rf $workdir' on $(hostname)"
        rm -rf $workdir
    fi
}
trap cleanup EXIT

echo "$(date) : timing for $prefix, start of samtools collate"
make -j $nCores -f ~/projects/pipeline/ppln/collateBam.mk PREFIX=$prefix INDIR=$indir OUTDIR=$workdir SUFFIX=realigned.recal INCLMK=$inclmk
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "samtools collate finished with an error"
    exit 1
fi
echo "$(date) : timing for $prefix, end of samtools collate"

echo "$(date) : timing for $prefix, start of samtools fastq"
make -j $nCores -f ~/projects/pipeline/ppln/fastq.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX=coll INCLMK=$inclmk

echo "$(date) : timing for $prefix, end of samtools fastq"
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "samtools fastq ${workdir}/${input_bam_basename}-coll.bam finished with an error"
    exit 1
fi
rm ${workdir}/${prefix}*.coll.bam

echo "$(date) : timing for $prefix start of bwa mem"
make -j $nCores -f ~/projects/pipeline/ppln/bwamem.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX= INCLMK=$inclmk NCORES=$nCores

echo "$(date) : timing for $prefix end of bwa mem"
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "bwa mem finished with an error"
    exit 1
fi
rm ${workdir}/${prefix}*.read*

echo "$(date) : timing for $prefix start of sambamba sort "
make -j $nCores -f ~/projects/pipeline/ppln/sortBam.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX=bwa NCORES=$nCores INCLMK=$inclmk

echo "$(date) : timing for $prefix end of sambamba sort "
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "sambamba sort finished with errors"
    exit 1
fi
rm ${workdir}/${prefix}*.bwa.bam

echo "$(date) : timing for $prefix start of sambamba markdup"
make -j $nCores -f ~/projects/pipeline/ppln/sambambaMarkDup.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX=re NCORES=$nCores INCLMK=$inclmk

ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "sambamba markdup finished wi errors"
    exit 1
fi
echo "$(date) : timing for $prefix end of sambamba markdup"
rm ${workdir}/${prefix}*.re.bam*

echo "$(date) : timing for $prefix start of gatk BaseRecalibrator"
make -j $nCores -f ~/projects/pipeline/ppln/baserecalibrate.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX=dp NCORES=$nCores INCLMK=$inclmk
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "gatk BaseRecalibrator finished wi errors"
    exit 1
fi
echo "$(date) : timing for $prefix end of gatk BaseRecalibrator"
rm ${workdir}/${prefix}*.dp.bam*

echo "$(date) : timing for $prefix start of sambamba index"
make -j $nCores -f ~/projects/pipeline/ppln/sambambaIndex.mk PREFIX=$prefix INDIR=$workdir OUTDIR=$workdir SUFFIX=rclb NCORES=$nCores INCLMK=$inclmk
ret=$?
echo $ret
if [ $ret -ne 0 ]; then
    echo "sambamba index finished wi errors"
    exit 1
fi
echo "$(date) : timing for $prefix end of sambamba index"

echo "$(date) : timing for $prefix start of pipe03"

~/projects/pipeline/ppln/pipe04.sh \
    $workdir \
    $workdir \
    $prefix \
    WG \
    0 \
    work \
    /mnt/xfs1/home/asalomatov/projects/pipeline/ppln/include_hg38.mk \
    YES \
    ,Freebayes,Platypus,HaplotypeCallerGVCF, \
    0 \
    /mnt/xfs1/home/asalomatov/projects/pipeline/ppln \
    $nCores \
    all \
    NO

echo "$(date) : timing for $prefix end of pipe03"

echo "$(date) : timing for $prefix start of moving to storage"

mv ${workdir}/${prefix}*.bam*  $output_dir
mv ${workdir}/${prefix}-HC.vcf.gz*  $output_dir
mv ${workdir}/${prefix}-FB.vcf.gz*  $output_dir
mv ${workdir}/${prefix}-PL.vcf.gz*  $output_dir
mv ${workdir}/*.g.vcf.gz* $output_dir
mv ${workdir}/logs $output_dir

echo "$(date) : timing for $prefix end of moving to storage"
echo "$(date) : timing for $prefix removing workdir"
rm -rf $workdir

echo "$(date) : timing for $prefix end of computation on $(hostname)"
