#!/bin/bash
#$ -N ${JOB_NAME}
#$ -V -j y -pe by_node ${SGE_PROC}
#$ -cwd -b y

export BOWTIE2_INDEXES=${BOWTIE2_INDEXES}

# run bowtie2 alignment
cd ${OUTPUT_DIR}

${BOWTIE2} -p ${BOWTIE2_PROC} \
      ${GENOME} \
      ${FASTQ1} ${FASTQ2} | samtools view -bS \
      -o ${BAMFILE} - 2> ${OUTPUT_ERR_LOG} > ${OUTPUT_LOG}  

# run bam stats upon completion
bam_stats -o ${BAMSTATS_OUTPUT} ${BAMFILE} 

samtools flagstat ${BAMFILE} 2>&1 | tee -a ${FLAGSTAT_LOG}