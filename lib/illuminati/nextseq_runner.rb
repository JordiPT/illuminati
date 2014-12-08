
#require 'terminal-table'
require 'illuminati/nextseq_samplesheet'

require 'illuminati/constants'

def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def yellow(text); colorize(text, 33); end
def cyan(text); colorize(text, 36); end

module Illuminati
  
  BASE_BIN_DIR = File.expand_path(File.dirname(__FILE__))
  LOGGER_SCRIPT = File.join(BASE_BIN_DIR, "logger.rb")
  EMAILER_SCRIPT = File.join(BASE_BIN_DIR, "emailer.rb")

  ## Testing 
  ## class NextSeqFlowcellPaths < FlowcellPaths
  ##   # Temorarily override FlowcellPaths to permit testing
  ##   # with symlinked directory structures, which begin with 99
  ##   # The base directory is the root directory for this flowcell.
  ##   # This means for us that it is the /solexa/*[FLOWCELL_ID] path.
  ##   #
  ##   def base_dir
  ##     # t
  ##     path = File.join(@paths.base, "99*#{@flowcell_id}")
  ##     paths = Dir.glob(path)
  ##     if paths.size < 1
  ##       puts "ERROR: no flowcell directory found for #{@flowcell_id}"
  ##       puts "ERROR: search path: #{path}"
  ##       raise "no flowcell path #{path}" unless @test
  ##     elsif paths.size > 1
  ##       puts "ERROR: multiple flowcell directories found for #{@flowcell_id}"
  ##       puts "ERROR: number of paths found: #{paths.size}"
  ##       raise "too many flowcell paths" unless @test
  ##     end
  ##     File.expand_path(paths[0])
  ##   end
  ## 
  ## end

  class ScriptWriter
    def initialize filename
      @filename = filename
      if File.exists?(@filename)
        puts "WARNING: #{@filename} exists. moving to #{@filename}.old"
        File.rename(@filename, @filename + ".old")
      end
      @script_file = File.open(@filename, 'w')
    end

    def write line
      @script_file << line << "\n"
    end

    def close
      @script_file.close
      system("chmod +x #{@filename}")
    end
  end

  class NextSeqRunner
      # Run the NextSeq pipeline
      
      @default_lanes_options = "1,2,3,4,5,6,7,8"
      
      def initialize flowcell_id, options
        
        puts flowcell_id
        puts options
        
        if options[:lanes] and options[:lanes].eql? @default_lanes_options
          puts red("--lanes is NOT a valid option for NextSeq pipeline.")
          exit
        end
        
        flowcell = FlowcellPaths.new flowcell_id
        #flowcell = NextSeqFlowcellPaths.new flowcell_id
        puts flowcell.base_dir
        
        # debug
        #temp_flowcell_script_path = "/Users/srm/tmp/#{flowcell.id}_tmp.sh"
        #bcl2fastq2_script_dir     = "/Users/srm/tmp/" #flowcell.base_dir
        #bowtie2_script_dir         = "/Users/srm/tmp/bowtie2/"
        #script = ScriptWriter.new temp_flowcell_script_path
        
        #vars = {:sample_sheet_file=>"SampleSheet.csv", :runfolder_dir=>"/Users/srm/tmp/"}
        vars = {:sample_sheet_file=>"SampleSheet.csv", :runfolder_dir=> flowcell.base_dir}
        
        script = ScriptWriter.new flowcell.script_path
        
        script.write "#!/bin/bash"
        script.write "# #{flowcell_id}"
        script.write ""
        
        command = "cd #{flowcell.base_dir}"
        script.write command
        script.write ""

        command = "#{ScriptPaths::lims_info} #{flowcell_id}"
        script.write command

        results = %x[#{command}]
        results.split("\n").each {|line| script.write "# #{line}" }

        #~/dev/illuminati/scripts/lims_fc_info.rb flowcell flowcell_id
        # "#{ScriptPaths::lims_info} #{flowcell_id}"
        
        bcl2fastq2_jobname = "nextseq_bcl2fastq2"
        
        # create external data lims
        fc_lims_data = Illuminati::ExternalDataLims.new 
        fc_sample_data = fc_lims_data.sample_data_for flowcell_id
        
        # create Sample sheet
        nxss = NextSeqSampleSheet.new vars, fc_sample_data
        
        bcl2fastq2_script_dir = flowcell.base_dir
        
        bowtie2_script_dir = File.join(flowcell.base_dir, NEXTSEQ_ALIGNED)        
        basecalls_dir = File.join(flowcell.base_dir, BASECALLS_PATH) 
        unaligned_dir = File.join(flowcell.base_dir, NEXTSEQ_UNALIGNED)
        
        # bcl2fastq2 command
        if not options[:skip_bcl2fastq2]
          vars[:job_name]      = bcl2fastq2_jobname
          vars[:sge_proc]      = BCL2FASTQ2_PROC
          vars[:path]          = "/n/ngs/tools/bcl2fastq2/current/bin/:$PATH"
          vars[:bcl2fastq2]    = BCL2FASTQ2_PATH #/n/ngs/tools/bcl2fastq2/current/bin/bcl2fastq 
          vars[:input_dir]     = basecalls_dir
          vars[:output_dir]    = unaligned_dir
          vars[:runfolder_dir] = flowcell.base_dir
          
          required_keys = [:job_name,:sge_proc,:path,:bcl2fastq2,:input_dir,:output_dir,:runfolder_dir]
          bcl2script = Illuminati::ScriptPaths.bcl2fastq2_script
          
          bcl2fastq2_command = generate_script vars, required_keys, bcl2script
          
          bcl2fastq2_script_name = "qsub_bcl2fastq2.sh"
          bcl2fastq2_script_full = File.join(bcl2fastq2_script_dir, bcl2fastq2_script_name)
          
          Dir.chdir(bcl2fastq2_script_dir)
          File.open(bcl2fastq2_script_name, 'w') do |f_bcl2fastq2|  
            f_bcl2fastq2.puts bcl2fastq2_command
          end
          
          # write qsub bcl2fastq2 commands
          bcl2fastq2_qsub = "qsub #{bcl2fastq2_script_full}"
          
          script.write ""
          script.write "# bcl2fastq2"
          script.write bcl2fastq2_qsub
          script.write ""
          
          #TODO: send email?
          command = "#{EMAILER_SCRIPT} \"starting bcl2fastq2 #{flowcell_id}\""
          script.write command
          script.write ""   
        end
        
        if not options[:skip_fastqc]
          # run fastq stats?
          fastqc_script = Illuminati::ScriptPaths.fastqc_script
          # error: not sure why flowcell.path.id doesn't resolve
          #command += " #{script} -v --flowcell #{flowcell.paths.id} --files \"*.fastq.gz\""
        
          command = " #{fastqc_script} -v --flowcell #{flowcell.id} --files \"*.fastq.gz\""
          
          fastqc_hold_jid = ""
          if not options[:skip_bcl2fastq2]
              fastqc_hold_jid = "-hold_jid #{bcl2fastq2_jobname}"
          end
          
          fastqc_qsub = "qsub #{fastqc_hold_jid} #{command}"
          
          script.write ""
          script.write "# fastqc"
          script.write fastqc_qsub
          script.write ""
        end
        
        if not options[:align]
          # 
          puts "NO ALIGN: #{options[:align]}"
        else
          # email 
          puts "ALIGN: #{options[:align]}"
          
          # write bowtie2 commands to file
          if not File.directory?(bowtie2_script_dir)
            system 'mkdir', '-p', bowtie2_script_dir
          end
          
          script.write "# bowtie2 alignments"
          #script.write table_results
          
          # run bowtie2_commands
          bowtie2_script = Illuminati::ScriptPaths.bowtie2_script
          
          bowtie2_array_script = Illuminati::ScriptPaths.bowtie2_array
          
          bowtie2_align_dir = File.join(flowcell.base_dir, NEXTSEQ_ALIGNED)
          
          # Aligned/bowtie2 => ../../Unaligned
          unaligned_relative = File.join("../../", NEXTSEQ_UNALIGNED, "/")
          
          fastq_records = nxss.get_fastq_records
          bowtie2_jobs_count = 0
          
          vars_global = {:bowtie2=>BOWTIE2, :bowtie2_proc=>BOWTIE2_PROC.to_i,
                         :job_name=>"nextseq_bowtie2", :output_dir=>bowtie2_align_dir}
          
          vars = vars_global
          fastq_table = [ ['genome','fastq1','fastq2'] ]
          fastq_records.each_index do |index|
            fq          = fastq_records[index]
            fastq_files = fq[:fastq]            
            # build a bowtie script for each fastq. Treat paired-end data as single-end.
            for lane_fq in fastq_files
              sge_proc    = BOWTIE2_SGE_PROC.to_i
              fastq_gunzip = "-%d <(gunzip -c %s%s)"
              for lane in lane_fq
                vars.update({:fastq1=>fastq_gunzip % [1, unaligned_relative, lane], :fastq2=>""})
                fq1 = lane
                fq2 = " "
                
                fastq_entry = [fq[:genome], fq1] 
                fastq_table << fastq_entry
                
                root            = lane_fq[1].gsub(/_001\.fastq\.gz/,"")
                bamfile         = root + ".bam"
                bamstats_output = root + "_bamstats.txt"
                output_err_log  = root + ".err"
                output_log      = root + ".log"
                flagstat_log    = root + "_flagstat.log"

                bowtie2_script_name = root + "_bowtie2.sh"
                bowtie2_script_full = File.join(bowtie2_script_dir, bowtie2_script_name)
                
                vars.update({:genome=>fq[:genome],:bamfile=>bamfile, :sge_proc=>sge_proc,
                             :output_err_log=>output_err_log, :flagstat_log=>flagstat_log,
                             :bamstats_output=>bamstats_output, :bowtie2_indexes=>BOWTIE2_INDEXES})
            
                required_keys = [:job_name,:sge_proc,:genome,:bowtie2,:bowtie2_proc,:fastq1,:fastq2,
                                 :bamfile,:output_err_log,:bamstats_output]
              
                bowtie2_command = generate_script vars, required_keys, bowtie2_script
            
                Dir.chdir(bowtie2_script_dir)
                File.open(bowtie2_script_full, 'w') do |f_bowtie2|  
                  f_bowtie2.puts bowtie2_command
                end
              
                # modify for array
                bowtie2_jobs_count += 1
                
              end # per fastq bowtie
            end # end lane
          end # end fastq_record   
          
          format_table fastq_table
          
          vars.update({:bowtie2_jobs_count=>bowtie2_jobs_count})
          
          required_keys = [:job_name,:sge_proc,:bowtie2_jobs_count,:bowtie2_indexes,:output_dir]
          
          bowtie2_array_command = generate_script vars, required_keys, bowtie2_array_script, ["bash"]
          
          bowtie2_array_script_full = File.join(bowtie2_script_dir, File.basename(bowtie2_array_script))
          
          Dir.chdir(bowtie2_script_dir)
          File.open(bowtie2_array_script_full, 'w') do |f_bowtie2|
            f_bowtie2.puts bowtie2_array_command
          end
            
          bcl2fastq2_hold_jid = ""
          if not options[:skip_bcl2fastq2]
            bcl2fastq2_hol_jid = "-hold_jid #{bcl2fastq2_jobname}"
          end
          
          command = "#{EMAILER_SCRIPT} \"starting bowtie2  #{flowcell_id}\""
          script.write command
          script.write ""
          
          script.write "cd #{unaligned_dir}"
          script.write ""
          
          # write qsub bowtie2 commands
          bowtie_qsub = "qsub  #{bcl2fastq2_hold_jid} #{bowtie2_array_script_full}"
          script.write bowtie_qsub
          
          
          script.write ""
          script.write ""
          
          exit
        
        end
      
      end
      
      def build_bcl2fastq2_command
        # requires ${BCL2FASTQ} ${INPUT_DIR} ${OUTPUT_DIR} ${RUNFOLDER_DIR}
        
      end
      
      def build_bowtie_commands
        # requires ${OUTPUT_DIR} ${BOWTIE2} -p ${BOWTIE2_PROC}
        # ${GENOME} ${FASTQ1} ${FASTQ2} ${BAMFILE} ${OUTPUT_ERR_LOG} ${OUTPUT_LOG}  
        # 
      end
      
      def nextseq
        # return @nextseq_check
        return true
      end
      
      def run_nextseq_pipeline
      end
      
      def format_table xs
        # xs is an array of equal sized arrays, i.e.
        # xs =[ ['Fastq1','Fastq2','genome'], 
        #       ['TEST1','TEST2','NONE'],
        #       ['TEST_TEST','TEST_TEST_TEST','NONE'] ]
        # source: http://stackoverflow.com/questions/603047/padding-printed-output-of-tabular-data
        max_lengths = xs[0].map { |_| _.length } # only use the first record
        xs.each do |x|
          x.each_with_index do |e, i|
            s = e.size
            max_lengths[i] = s if s > max_lengths[i]
          end
        end
        xs.each do |x|
          format = max_lengths.map { |_| "%#{_}s" }.join(" " * 5)
          puts format % x
        end
      end
      
      
      def missing_placeholder(placeholder, values)
        "%{#{placeholder}}"
      end
      
      # string interpolation for only keys with matching values.
      # used to substitute for qsub array job script, where
      # the last line `bash -c ${BOWTIE2[${i}]}` should NOT
      # be replaced with ruby values, but rather allowed for bash substitution values.  
      def interpolate_hash(string, values)
        # ripped from: https://github.com/mova-rb/mova/blob/25cfb40a71ad4b4c51a7c429570f78d636beb18a/lib/mova/interpolation/sprintf.rb
        # MIT LICENSED
        placeholder_re = Regexp.union(
          /%%/,         # escape character
          /%\{(\w+)\}/, # %{hello}
          /%<(\w+)>(.*?\d*\.?\d*[bBdiouxXeEfgGcps])/ # %<hello>.d
        )
        escape_sequence = "%%".freeze
        escape_sequence_replacement = "%".freeze
        
        string.to_str.gsub(placeholder_re) do |match|
          if match == escape_sequence
            escape_sequence_replacement
          else
            placeholder = ($1 || $2).to_sym
            replacement = values[placeholder] || "${#{placeholder}}" #missing_placeholder(placeholder, values, string)
            $3 ? sprintf("%#{$3}", replacement) : replacement
          end
        end
      end
      
      def generate_script vars, required_keys, script, interpolate_hash=nil
        # IMPORTANT, when interpolation is done with the custom interpolate
        # hash method above, missing keys will NOT generate a KeyError, 
        # likely resulting in downstream errors.
        unless required_keys.all? {|s| vars.key? s}
          missing_keys = (required_keys - vars.keys)
          puts "ERROR: missing required keys #{missing_keys}"
          exit
        end
      
        # put vars case to uppercase strings for substitution in bash script
        vars_upper = vars.inject({}) { |h, (k, v)| h[k.upcase] = v; h }
        
        script_contents = File.read(script)
        script_contents = script_contents.gsub('${', '%{')
        
        #puts interpolate_hash(script_contents, vars_upper)
        if interpolate_hash.nil?
          command = script_contents % vars_upper
        else
          command = interpolate_hash(script_contents, vars_upper) 
          # return un-interpolated values back to bash substitution format
          command = command.gsub('%{','${')
        end
        
        command
      end
      
      
    end
end
