## *remap2b38*

### Overview

*remap2b38* contains one script *remap.sh* that can be used to remap a bam file to 
a new reference genome, and to call variants with a choice of GATK HaplotypeCaller,
Freebayes, and Platypus using [*pipeline*](https://github.com/simonsfoundation/pipeline.git)

The following steps will be executed.

    1. samtools collate
    2. samtools fastq
    3. bwa mem
    3. sambamba sort
    4. sambamba markdup
    5. GATK base quality recalibrate
    6. sambamba index
    7. pipe04.sh from *pipeline* to call variants on this sample/family

If you do not wish to call variants, comment out pipe04.sh call.

##Dependences.

*samtools* and *sambamba* must be in your $PATH.

Clone *pipeline*.
```
cd ~
git clone https://github.com/simonsfoundation/pipeline.git
```   

Clone this repo
```
cd ~
git clone https://github.com/simonsfoundation/remap2b38.git
```

Run
```
~/remap2b38/remap.sh \
   bam_prefix \ # eg 123, if bam(s) are 123*.bam
   /path/to/iput_bams_dir/ \ # directory containing files defined by the prefix
   scr \ # tmp/scr/work defines working dir, see comments in remap.sh
   /path/to/output_dir/ \ # output directory (will be created)
   1 \ # 1/0 remove working_dir/do not remove
   8 \ # use this many cores
   /path/to/pipeline/ppln \ # e.g. ~/, if you followed instructions above
   > /path/to/log_file.log 2>&1
```



