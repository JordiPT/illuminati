#!/bin/bash
#$ -N ${JOB_NAME}
#$ -V -j y -pe orte ${SGE_PROC}
#$ -cwd -b y -t 1-${BOWTIE2_JOBS_COUNT}:1
export BOWTIE2_INDEXES=${BOWTIE2_INDEXES}

# run bowtie2 alignment
cd ${OUTPUT_DIR}

BOWTIE2_SCRIPTS=($(find . -maxdepth 1 -iname "*_bowtie2.sh")) 

i=$(expr $SGE_TASK_ID - 1)

bash -c ${BOWTIE2_SCRIPTS[${i}]}
