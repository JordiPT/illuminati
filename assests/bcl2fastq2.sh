#!/bin/bash
#$ -N ${JOB_NAME}
#$ -V -j y -pe by_node ${SGE_PROC}
#$ -cwd -b y -v PATH=${PATH}

# run bcl2fastq, if SGE_PROC
${BCL2FASTQ2} --ignore-missing-bcls --barcode-mismatches 1 \
  --processing-threads 3 --demultiplexing-threads 2 \
  --input-dir ${INPUT_DIR} \
  --output-dir ${OUTPUT_DIR} \
  --runfolder-dir ${RUNFOLDER_DIR}


