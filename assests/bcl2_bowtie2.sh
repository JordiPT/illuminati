#!/bin/bash
#$ -N ${JOB_NAME}
#$ -V -j y -pe by_node ${SGE_PROC}
#$ -cwd -b y -v PATH ${PATH}

# run bcl2fastq, if SGE_PROC
${BCL2FASTQ} --ignore-missing-bcls --barcode-mismatches 1 \
  --processing-threads 3 --demultiplexing-threads 2 \
  --input-dir ${INPUT_DIR} \
  --output-dir ${OUTPUT_DIR} \
  --runfolder-dir ${RUNFOLDER_DIR}

# run bowtie2 alignment
cd ${OUTPUT_DIR}

${BOWTIE2} -p ${BOWTIE2_PROC} -k 1 \
      ${GENOME} \
      ${FASTQ1} ${FASTQ2} | samtools view -bS -o ${BAMFILE} - 2> ${OUTPUT_ERR_LOG} > ${OUTPUT_LOG}  

# run bam stats upon completion TODO: need to specify names... 
# find . -iname "*.bam" -exec bam_stats {} \;

