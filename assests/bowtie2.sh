#!/bin/bash
#$ -N ${JOB_NAME}
#$ -V -j y -pe orte ${SGE_PROC}
#$ -cwd -b y

export BOWTIE2_INDEXES=${BOWTIE2_INDEXES}

echo `pwd`

# run bowtie2 alignment
cd ${OUTPUT_DIR}

echo `pwd`

${BOWTIE2} -p ${BOWTIE2_PROC} \
      ${GENOME} \
      ${FASTQ1} ${FASTQ2} 2> ${OUTPUT_ERR_LOG} | samtools view -bS -o ${BAMFILE} -

# run bam stats upon completion
bam_stats -o ${BAMSTATS_OUTPUT} ${BAMFILE} 

samtools flagstat ${BAMFILE} 2>&1 | tee -a ${FLAGSTAT_LOG}
