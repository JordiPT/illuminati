#n/ngs/tools/bcl2fastq2/current/build/bin/bcl2fastq --ignore-missing-bcls --barcode-mismatches 1 --input-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX/Data/Intensities/BaseCalls --output-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX/Unaligned --runfolder-dir /n/ngs/data/140619_NS500406_0001_AH0UD3AGXX


# command = "#{BCL2FASTQ2_PATH} --ignore-missing-bcls --barcode-mismatches 1 --input-dir #{flowcell.base_calls_dir} --output-dir #{flowcell.unaligned_dir} --runfolder-dir #{flowcell.base_dir}"

# bcl2fastq2 cmd
command = "#{BCL2FASTQ_PATH}/configureBclToFastq.pl --ignore-missing-stats --mismatches 1 --input-dir #{flowcell.base_calls_dir} --output-dir #{flowcell.unaligned_dir}  --flowcell-id #{flowcell.flowcell_id}"


ALIGN_SCRIPT = File.join(BASE_BIN_DIR, "align_runner.rb")

class BowtieRunner

  #$bowtie2 = "/n/local/stage/bowtie2/bowtie2-2.1.0/bowtie2";
  #$genome = "/n/ngs/igenome/phiX/bowtie2/phix";

  #$com = "($bowtie2 -k 1 $genome <(gunzip -c $file) | samtools view -bS -o $outputdir/$alias.bam - ) 2> $outputdir/$alias.err > $outputdir/$alias.out && mail -s pipeline.bowtie2.$alias.end mcm\@stowers.org < /dev/null &";

  #$com = "($bowtie2 -p 2 -k 1 $genome -1 <(gunzip -c $file) -2 <(gunzip -c $read2) | samtools view -bS -o $outputdir/$alias.bam - ) 2> $outputdir/$alias.err > $outputdir/$alias.out && mail -s pipeline.bowtie2.$alias.end mcm\@stowers.org < /dev/null &";

  bowtie2 = config['bowtie2_path']
  bowtie2_proc = config['bowtie2_proc']
  genome = File.join(config['bowtie2_genome_root'], sample_data[:species])
  
  @fastq1 = "-1 <(gunzip -c #{sample_data[:fastq1]})"

  if sample_data[:protocol] == "eland_pair"
    @fastq2 = "-2 <(gunzip -c #{sample_data[:fastq2]})"
  else
    @fastq2 = ""
  end
  
  #qsub = "qsub -cwd -v PATH #{BOWTIE2_PATH}"
  #command = "cd #{OUTPUT_DIR}; #{BOWTIE2} -p #{BOWTIE2_PROC} -k 1 #{GENOME} #{FASTQ1} #{FASTQ2} | samtools view -bS -o #{BAMFILE} - 2> #{OUTPUT_ERR_LOG} > #{OUTPUT_LOG}"
    
  ${JOB_NAME} ${SGE_PROC} ${PATH}
  ${BCL2FASTQ} ${BCL_INPUT_DIR} ${BCL_OUTPUT_DIR} ${RUNFOLDER_DIR}
  
  ${OUTPUT_DIR}

  ${BOWTIE2} ${BOWTIE2_PROC} ${GENOME} ${FASTQ1} ${FASTQ2} ${BAMFILE} ${OUTPUT_ERR_LOG} ${OUTPUT_LOG}  
  
  
  
  def generate_script vars
    required_keys = [:job_name,:sge_proc,:path,:bcl2fastq,:bcl_input_dir,:bcl_output_dir,:runfolder_dir,
                     :genome,:output_dir,:bowtie2,:bowtie2_proc,:fastq1,:fastq2,
                     :bamfile,:output_err_log,:output_log]
    
    unless required_keys.all? {|s| vars.key? s}
      missing_keys = (required_keys - vars.keys)
      puts "ERROR: missing required keys #{missing_keys}"
      exit
    end
    
    # put vars case to uppercase strings for substitution in bash script
    vars_upper = vars.inject({}) { |h, (k, v)| h[k.upcase] = v; h }
    
    script = Illuminati::ScriptPaths.bowtie2_script
    script_contents = File.read(script)
    script_contents = script_contents.gsub('${', '%{')
    
    command = script_contents % vars_upper
    
    command
  end
  
  def write_script
    # options: job_name, sge_proc, bcl2fastq, bcl_input_dir,bcl_output_dir,runfolder_dir  
    #          genome, output_dir, bowtie2, bowtie2_proc, 
    
    
    vars = {:fastq1=>@fastq1,:fastq2=>@fastq2}
    
    #vars = {:job_name=>@job_name,:output_file=>@bam_name, :output_log => @output_log, 
    #        :output_dir => @output_dir, :genome => @genome, 
    #        :gtf=> @gtf, :txi=>@txi, :strand_specific => @strand_specific, :fastq_file=>@fastq_file} #.merge(default_vars)
    
    vars.update(@options){|key,v1| f(v1)}
    @job_name = vars[:job_name]
    @output_dir = vars[:output_dir]
    if not File.directory?(@output_dir)
      system 'mkdir', '-p', @output_dir
    end
    @tophat_script = self.generate_tophat_script vars
    Dir.chdir(@output_dir)
    File.open(@tophat_script_file, 'w') do |f_tophat|  
      f_tophat.puts @tophat_script
    end
    @tophat_script_full_path = File.join(@output_dir, @tophat_script_file)
    
  end

  def set_sample_name sample_name
    sample_name.gsub(/[^0-9a-z\-_]/i, '').downcase
  end
  


end