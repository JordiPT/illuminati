#n/ngs/tools/bcl2fastq2/current/build/bin/bcl2fastq --ignore-missing-bcls --barcode-mismatches 1 --input-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX/Data/Intensities/BaseCalls --output-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX/Unaligned --runfolder-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX


# command = "#{BCL2FASTQ2_PATH} --ignore-missing-bcls --barcode-mismatches 1 --input-dir #{flowcell.base_calls_dir} --output-dir #{flowcell.unaligned_dir} --runfolder-dir #{flowcell.base_dir}"

# bcl2fastq2 cmd
command = "#{BCL2FASTQ_PATH}/configureBclToFastq.pl --ignore-missing-stats --mismatches 1 --input-dir #{flowcell.base_calls_dir} --output-dir #{flowcell.unaligned_dir}  --flowcell-id #{flowcell.flowcell_id}"

${JOB_NAME} ${SGE_PROC} ${PATH}
${BCL2FASTQ} ${BCL_INPUT_DIR} ${BCL_OUTPUT_DIR} ${RUNFOLDER_DIR}

:bcl2fastq,:bcl_input_dir,:bcl_output_dir,:runfolder_dir,

# options
bcl2fastq, bcl_input_dir,bcl_output_dir,runfolder_dir

ALIGN_SCRIPT = File.join(BASE_BIN_DIR, "align_runner.rb")

class Bcl2fastq2Runner


end
