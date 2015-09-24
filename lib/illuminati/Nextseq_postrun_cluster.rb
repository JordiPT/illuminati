require 'parallel'
require 'illuminati/emailer'

module Illuminati
  BASE_BIN_DIR = File.expand_path(File.dirname(__FILE__))
  #
  # The most complicated and least well implemented of the Illuminati classes.
  # PostRunner is executed after the alignment step has completed. It Performs all the
  # steps necessary to convert the output of CASAVA into output we want to use and
  # ship that output to the proper places. Here's some of what PostRunner does:
  #
  # * Rename fastq.gz files
  # * Filter fastq.gz files
  # * Split lanes with custom barcodes
  # * Run fastqc on fastq.gz files
  # * Create Sample_Report.csv
  # * Distribute fastq.gz files to project directories
  # * Distribute qc / stats data to project directories
  # * Distribute qc / stats data to qcdata directory
  # * Rename export files
  # * Distribute export files to project directories
  #
  # The --steps option can be used to limit which steps are performed by the post run process.
  # Right now, check out the run method to see how this works.
  #
  # So there is a lot going down here. It uses Flowcell path data extensively for
  # determining what goes where. It also uses another class to get distribution data which
  # pulls this info from LIMS.
  #
  # The run method is the main starting point that kicks off all the rest of the process.
  # When done, the primary analysis pipeline should be considered complete.
  #
  class NextSeqPostRunnerCluster
    attr_reader :flowcell
    attr_reader :options
    ALL_STEPS = %w{fastqc distribution_bylane distribution_all report lims_upload}
    DEFAULT_STEPS = %w{fastqc distribution_bylane report lims_upload}


    #
    # New PostRunner instance
    #
    # == Parameters:
    # flowcell::
    #   Flowcell data instance. Passed in to help with testing.
    # options::
    #   Hash of options to configure runner.
    #   :test - is the runner in test mode?
    #
    def initialize flowcell, options = {}
      options = {:test => false, :steps => ALL_STEPS}.merge(options)

      options[:steps].each do |step|
        valid = true
        unless ALL_STEPS.include? step
          puts "ERROR: invalid step for nextseq postrun: #{step}"
          valid = false
        end

        if !valid
          puts "Valid steps for nextseq postrun: #{ALL_STEPS.join(", ")}"
          raise "Invalid Step"
        end
      end

      @flowcell = flowcell
      @options = options
      @post_run_script = nil
    end

    #
    # Helper method that executes a given string on the command line.
    # This should be used instead of calling system directly, as it also
    # deals with if we are in test mode or not.
    #
    def execute command
      log command
      system(command) unless @options[:test]
    end

    #
    # Poorly named. This adds a message to the script output file.
    # Also outputs message to standard out.
    #
    def log message
      puts message
      if @post_run_script and !@post_run_script.closed?
        @post_run_script << message << "\n"
      end
    end

    #
    # Poorly named. Uses the logger module to output the current
    # status of the post run process.
    #
    def status message
      log "# #{message}"
      SolexaLogger.log(@flowcell.paths.id, message) unless @options[:test]
    end

    #
    # Helper method to print a title section in the
    # post run output
    #
    def title message
      log "#########################"
      log "## #{message}"
      log "#########################"
    end

    #
    # Returns boolean if all files input exist.
    # Also logs missing files using log method
    #
    # == Parameters:
    # files::
    #   Array of file paths
    #
    def check_exists files
      files = [files].flatten
      rtn = true
      files.each do |file|
        if !file or !File.exists?(file)
          log "# Error: file not found:#{file}."
          rtn = false unless @options[:test]
        end
      end
      rtn
    end

    #
    # Startup tasks to begin post run.
    # Should be called by run, but not directly.
    #
    def start_flowcell
      Emailer.email "starting Nextseq post run for #{@flowcell.paths.id}" unless @options[:test]
      status "Nextseq postrun start"

      @post_run_script_filename = File.join(@flowcell.paths.base_dir, "nextseq_postrun_#{@flowcell.paths.id}.sh")
      @post_run_script = File.new(@post_run_script_filename, 'w')
    end

    #
    # Teardown process of post run.
    # Should not be called externally.
    #
    def stop_flowcell wait_on_task
      @post_run_script.close if @post_run_script
      #qc_postrun_filename = File.join(@flowcell.paths.qc_dir, File.basename(@post_run_script_filename))
      #execute "cp #{@post_run_script_filename} #{qc_postrun_filename}"
      submit_one("nextseq_postrun", "email", wait_on_task, "POSTRUN", @flowcell.paths.id)
      status "postrun done"
    end

    #
    # Main entry point to PostRunner. Starts post run process and executes all
    # required steps to getting data and files in to the way we want them.
    #
    def run
      start_flowcell
      distributions = []

      unless @options[:no_distribute]
        distributions = @flowcell.external_data.distributions_for @flowcell.id
      end
 
      log "# #{distributions.join(",")}"

      if distributions.empty?
        log "ERROR: No distributions found"
      end

      steps = @options[:steps]
      status "running steps: #{steps.join(", ")}"
      wait_on_task = nil
      unaligned_task = nil
=begin
      if steps.include? "filter"
        # unaligned dir
        filter_task = process_raw_reads distributions
        wait_on_task = filter_task
        log "wait_on_task: #{wait_on_task}"
        submit_one("filter", "email", wait_on_task, "FILTER", @flowcell.paths.id)
        # Emailer.email "UNALIGNED step finished for #{@flowcell.paths.id}" unless @options[:test]
      end

      if steps.include? "custom"
        unaligned_task = process_custom_barcode_reads distributions, unaligned_task
        submit_one("custom", "email", custom_task, "CUSTOM", @flowcell.paths.id)
      end

      if steps.include? "undetermined"
        
        log "undetermined waiting on: #{wait_on_task}"
        unaligned_task = process_undetermined_reads distributions, wait_on_task
        wait_on_task = unaligned_task
        log "wait_on_task: #{wait_on_task}"
        submit_one("undetermined", "email", wait_on_task, "UNDETERMINED", @flowcell.paths.id)
      end
=end

      
      if steps.include? "fastqc"
        #puts @flowcell.paths.nextseq_fastqc_dir
  
        system("mkdir -p #{@flowcell.paths.nextseq_fastqc_dir}")
        fastqc_task = nil
        distributions = [distributions].flatten
        unique_distributions = distributions.collect {|d| d[:path]}.uniq
        full_distribution_path = File.join(unique_distributions, "fastqc")
        system("mkdir -p #{full_distribution_path}")
        unless @options[:only_distribute]
          log "# fastqc waiting on: #{wait_on_task}"
          fastqc_task = parallel_run_fastqc @flowcell.paths.fastq_combine_dir, wait_on_task, distributions
        end

        wait_on_task = fastqc_task
        log "wait_on_task: #{wait_on_task}"
        #submit_one("fastqc", "email", wait_on_task, "FASTQC", @flowcell.paths.id)

      end


      if steps.include? "distribution_bylane"
        fastq_distribution_task = parallel_distribute_fastq "fastq", distributions, @flowcell.paths.unaligned_dir

        wait_on_task = fastq_distribution_task
        log "wait_on_task: #{fastq_distribution_task}"
        #submit_one("fastq", "email", wait_on_task, "FASTQ", @flowcell.paths.id)


      end


      if steps.include? "distribution_all"
        #puts @flowcell.paths.fastq_combine_dir
        fastq_distribution_task = parallel_distribute_fastq "fastq", distributions, @flowcell.paths.fastq_combine_dir, "all"

        wait_on_task = fastq_distribution_task
        log "wait_on_task: #{fastq_distribution_task}"
        #submit_one("fastq", "email", wait_on_task, "FASTQ", @flowcell.paths.id)


      end


      if steps.include? "report"
        nextseq_create_sample_report @flowcell.paths.base_dir, distributions

        #distribute_sample_report distributions
      end

      if steps.include? "lims_upload"
        upload_lims("SampleReportGenerator")
      end


=begin
   
       if steps.include? "qcdata"
        distribute_to_qcdata
      end
      
      if steps.include? "aligned"
        log "aligned waiting on: #{wait_on_task}"
        aligned_task = run_aligned distributions, wait_on_task
        wait_on_task = aligned_task
        log "wait_on_task: #{wait_on_task}"
        submit_one("aligned", "email", wait_on_task, "ALIGNED", @flowcell.paths.id)
      end

      if steps.include? "stats"
        create_custom_stats_files
        distribute_custom_stats_files distributions
      end

      if steps.include? "lims_upload"
        upload_lims(wait_on_task)
      end

      if steps.include? "lims_complete"
        wait_time = 5
        if steps.include? "fastqc"
          wait_time = 40
        end
        complete_lims(wait_on_task, wait_time)
      end
=end
       stop_flowcell(wait_on_task)
    end

    def upload_lims dependency
      status "uploading Sample Report to lims"

      task_name = submit_one("lims", "lims_upload", dependency, "#{@flowcell.id}","nextseq")
    end


    def parallel_distribute_fastq prefix, distributions, full_source_paths, dependency = nil
      puts dependency
      database = []
      fastq_files = Dir.glob(File.join(full_source_paths, "*.fastq.gz"))
      # puts fastq_files
      fastq_file_data = get_file_data fastq_files, "\.fastq\.gz", dependency

      #puts fastq_file_data

      distribution_single = [distributions].flatten
      full_source_paths_single = [full_source_paths].flatten

      if dependency == "all"
        fastq_file_data.each do |fastq_file_data|
          entry = {:input => fastq_file_data[:path], :output => distribution_single[0][:path], :recursive => false}
          database << entry
        end

      else

        distributions.each do |distributions|
          distributions[:path] = "#{distributions[:path]}bylane_fastq"
          log "# Creating directory #{distributions[:path]}"
          execute "mkdir -p #{distributions[:path]}"

          fastq_file_data.each do |fastq_file_data|
            if distributions[:lane].to_i == fastq_file_data[:lane].to_i
              #rename fastq files when cp
              #if(fastq_file_data[:library]=="Undetermined")
              #  fastq_newname = "#{distributions[:path]}n_#{fastq_file_data[:lane]}_#{fastq_file_data[:replicates]}_Undetermined.fastq.gz"
              #else
              #  fastq_library,fastq_barcode=fastq_file_data[:library].split(/-/)
              #  fastq_newname = "#{distributions[:path]}n_#{fastq_file_data[:lane]}_#{fastq_file_data[:replicates]}_#{fastq_barcode}.fastq.gz"
              #end
              #entry = {:input => fastq_file_data[:path], :output => fastq_newname, :recursive => false}

              entry = {:input => fastq_file_data[:path], :output => distributions[:path], :recursive => false}

              database << entry

            end
          end

          if database==[]
            puts "# Wrong mapping, copy file using single thread"
            full_source_paths_single.each do |full_source_paths_single|
              next unless check_exists(full_source_paths_single)
              already_distributed = []
              source_path = File.basename(full_source_paths_single)

              distribution_single.each do |distribution_single|
                full_source_paths_single = File.join(distribution_single[:path], source_path)
                unless already_distributed.include? full_source_paths_single
                  already_distributed << full_source_paths_single
                  distribution_dir = File.dirname(full_source_paths_single)
                  execute "mkdir -p #{distribution_dir}" unless File.exists? distribution_dir
                  if File.directory? full_source_paths_single
                    log "# Creating directory #{full_source_paths_single}"
                    execute "mkdir -p #{full_source_paths_single}"
                  end
                  database << {:input => full_source_paths_single, :output => distribution_dir, :recursive => true}
                end
              end
            end

          end
        end
      end

      #puts database

    task_id = submit_parallel(prefix, "cp_files", database, false, true)
    task_id

    end


    def get_file_data files, suffix_pattern = "\.fastq\.gz",dependency=nil
      files = [files].flatten

      #$NAME_PATTERN = /(.*)_([ATCGN-]+|NoIndex|Undetermined)_L(\d{3})_R(\d)_(\d{3})#{suffix_pattern}/


      if dependency == "all"
        $NAME_PATTERN = /(n)_(\d)_([ATCGN-]+|NoIndex|Undetermined)#{suffix_pattern}/
        file_data = files.collect do |file|
          base_name = File.basename(file)
          match = base_name =~ $NAME_PATTERN
          raise "ERROR: #{file} does not match expected file name pattern" unless match
          data = {:lane => "nextseq", :path => file}
          data
        end
      else
        $NAME_PATTERN = /(n)_(\d)_(\d)_([ATCGN-]+|NoIndex|Undetermined)#{suffix_pattern}/
        file_data = files.collect do |file|
          base_name = File.basename(file)
          match = base_name =~ $NAME_PATTERN
          raise "ERROR: #{file} does not match expected file name pattern" unless match
          data = {:lane => $2.to_i, :path => file}
          data
        end
      end
      # 1_ACTTGA_ACTTGA_L001_R1_002.fastq.gz
      # $1 = "1_ACTTGA"
      # $2 = "ACTTGA"
      # $3 = "001"
      # $4 = "1"
      # $5 = "002"


    end


    def submit_parallel prefix, task_name, database, dependency = nil, sync = nil
      cwd = Dir.pwd
      # get child cat script
      child_process_script = File.join(ASSESTS_PATH, "#{task_name}.rb")

      if !File.exists?(child_process_script)
        log "# ERROR: no process script found: #{child_process_script}"
        return nil
      end

      wrapper_script = File.join(ASSESTS_PATH, "wrapper.sh")
      if !File.exists?(wrapper_script)
        log "# ERROR: no wrapper script found: #{wrapper_script}"
        return nil
      end
      full_task_name = "#{prefix}_#{task_name}"

      # save database to place that can be
      # found by child processes
      db_filename = File.expand_path(File.join(@flowcell.paths.qsub_db_path, "#{full_task_name}.json"))

      command = "mkdir -p #{File.dirname(db_filename)}"
      execute command

      File.open(db_filename, 'w') do |file|
        file.puts database.to_json
      end


      Dir.chdir(@flowcell.paths.qsub_db_path) do
        # run for all jobs in database
        command = "qsub -cwd -V"
        if dependency
          command += " -hold_jid #{dependency}"
        end

        if sync
          command += " -sync y"
        end
        command += " -t 1-#{database.size}:1 -N #{full_task_name} #{wrapper_script} #{child_process_script} #{db_filename}"
        execute(command)
      end
      full_task_name
    end


    def group_fastq_files starting_path, output_path, options = {:prefix => "s_", :suffix => ".fastq.gz", :exclude_undetermined => true}
      execute "mkdir -p #{output_path}"
      fastq_groups = []

      fastq_files = Dir.glob(File.join(starting_path, "**", "*.fastq.gz"))
      if fastq_files.empty?
        log "# ERROR: no fastq files found in #{starting_path}" if fastq_files.empty?
      else
        log "# #{fastq_files.size} fastq files found in #{starting_path}"
        fastq_file_data = get_file_data fastq_files, "\.fastq\.gz"
        fastq_groups = group_files fastq_file_data, output_path, options
      end
      fastq_groups
    end
    


  
    #
    # Calls SampleReportMaker to create Sample_Report.csv
    #
    def nextseq_create_sample_report report_path, distributions = []
      status "creating nextseq Sample_Report.csv from bowtie"

      unique_distributions = distributions.collect {|d| d[:path]}.uniq
      puts unique_distributions
      cwd = Dir.pwd

      if check_exists(report_path)
        bowtie_dir = @flowcell.paths.aligned_bowtie_dir
        execute "cd #{report_path}"
        execute "export PATH=$PATH:/n/local/stage/perlbrew/perlbrew-0.43/perls/perl-5.16.1t/bin/perl"
        command1 = "qsub -cwd -hold_jid \"fastqc*\" -N SampleReport1Generator -v PATH /n/ngs/tools/pilluminati/assests/wrapper2.sh \"perl /n/ngs/tools/pilluminati/scripts/nextseq_sample_report.pl -f #{@flowcell.id} -b #{bowtie_dir} -d #{bowtie_dir} -w #{report_path}\""
        command2 = "qsub -cwd -hold_jid \"fastqc*\" -N SampleReport2Generator -v PATH /n/ngs/tools/pilluminati/assests/wrapper2.sh \"perl /n/ngs/tools/pilluminati/scripts/nextseq_sample_report.by_lane.pl -f #{@flowcell.id} -b #{bowtie_dir} -d #{bowtie_dir} -w #{report_path}\""

        execute command1
        execute command2

        execute "qsub -cwd -hold_jid SampleReport1Generator -N copy1_report /n/ngs/tools/pilluminati/assests/wrapper2.sh \"cp  #{report_path}/Sample_Report.csv  #{unique_distributions[0]}\""
        execute "qsub -cwd -hold_jid SampleReport2Generator -N copy2_report /n/ngs/tools/pilluminati/assests/wrapper2.sh \"cp  #{report_path}/Sample_Report.by_lane.csv  #{unique_distributions[0]}/bylane_fastq\""

      end
      
    end

    #
    # Distriubutes Sample_Report.csv to project directories
    #
    def distribute_sample_report distributions
      status "distributing sample_report"
      #distribute_to_unique distributions, @flowcell.paths.sample_report_path
    end
 
    
    #FASTQC STEPS STARTED
    # Runs fastqc on all relevant files in fastq_path
    # output is genearted fastq_path/fastqc
    #
    def parallel_run_fastqc fastq_path, dependency = nil, distributions = []
      status "running fastqc"
      prefix = "fastqc"
      #puts "---"+fastq_path.to_s+"---"+distributions.to_s
      cwd = Dir.pwd
      task_name = nil
      output_filename = create_fastqc_database(fastq_path, distributions)
      if check_exists(fastq_path)
        task_name = submit_one(prefix, "fastqc", dependency, "#{fastq_path} #{output_filename}")
      end
      task_name
    end
    
    def create_fastqc_database fastq_path, distributions
      output_filename = File.join(fastq_path, "fastqc","fastqc_starting_data.json")

      system("mkdir -p #{File.dirname(output_filename)}")
      database = {}
      unique_distributions = distributions.collect {|d| d[:path]}.uniq

      database["flowcell_id"] = @flowcell.paths.id
      unless unique_distributions.empty?
        database["projects"] = unique_distributions
      end

      File.open(output_filename, 'w') do |file|
        file.puts database.to_json
      end

      output_filename
    end
    
    #
    # Runs fastqc on all relevant files in fastq_path
    # output is genearted fastq_path/fastqc
    #
    def run_fastqc fastq_path
      status "running fastqc"
      cwd = Dir.pwd
      puts fastq_path
      if check_exists(fastq_path)
        command = "cd #{fastq_path};"
        script = Illuminati::ScriptPaths.fastqc_script
        command += " #{script} -v --files \"*.fastq.gz\""

        execute command
        execute "cd #{cwd}"
      end
    end

    def submit_one prefix, task_name, dependency = nil, *args
      cwd = Dir.pwd
      # get child cat script
      child_process_script = File.join(ASSESTS_PATH, "#{task_name}.rb")

      if !File.exists?(child_process_script)
        log "# ERROR: no process script found: #{child_process_script}"
        return nil
      end

      wrapper_script = File.join(ASSESTS_PATH, "wrapper.sh")
      if !File.exists?(wrapper_script)
        log "# ERROR: no wrapper script found: #{wrapper_script}"
        return nil
      end

      full_task_name = "#{prefix}_#{task_name}"

      system("mkdir -p #{@flowcell.paths.qsub_db_path}")

      Dir.chdir(@flowcell.paths.qsub_db_path) do
        # run for all jobs in database
        command = "qsub -cwd -V"
        if dependency
          command += " -hold_jid #{dependency}"
        end
        command += " -N #{full_task_name} #{wrapper_script} #{child_process_script} #{args.join(" ")}"
        execute(command)
      end
      full_task_name
    end
  #FASTQC STEPS END HERE  

=begin
 
  
#QCDATA STEP STARTED HERE
    # Collects and distributes all the files needed to go to the qcdata
    # directory.
    #
    def distribute_to_qcdata
      status "distributing to qcdata"
      puts @flowcell.paths.qc_dir
      execute "mkdir -p #{@flowcell.paths.qc_dir}"
      distribution = {:path => @flowcell.paths.qc_dir}
        = ["InterOp", "RunInfo.xml", "Events.log", "Data/reports"]
      qc_paths = qc_files.collect {|qc_file| File.join(@flowcell.paths.base_dir, qc_file)}
      distribute_to_unique distribution, qc_paths
      distribute_to_unique distribution, @flowcell.paths.unaligned_stats_dir
      distribute_custom_stats_files distribution
      distribute_to_unique distribution, @flowcell.paths.fastqc_dir
      distribute_sample_report distribution
    end
    
    #
    # Given an array of distributions and an array of file paths
    # this method copies each file in the file paths to each distribution
    # but ensures this process only occurs once to avoid copying to the same
    # project directory mulitiple times.
    #
    def distribute_to_unique distributions, full_source_paths
      #puts full_source_paths
      distributions = [distributions].flatten
      full_source_paths = [full_source_paths].flatten
      full_source_paths.each do |full_source_path|
        if check_exists(full_source_path)
          already_distributed = []
          source_path = File.basename(full_source_path)

          distributions.each do |distribution|
            full_distribution_path = File.join(distribution[:path], source_path)
            unless already_distributed.include? full_distribution_path
              already_distributed << full_distribution_path

              distribution_dir = File.dirname(full_distribution_path)
              execute "mkdir -p #{distribution_dir}" unless File.exists? distribution_dir

              if File.directory? full_source_path
                log "# Creating directory #{full_distribution_path}"
                execute "mkdir -p #{full_distribution_path}"
              end
              command = "cp -r #{full_source_path} #{distribution_dir}"
              execute command
            end
          end
        end
      end
    end
 #QCDATA STEPS END HERE
    #
    # Executes commands related to fastq.gz files including
    # filtering them and distributing them.
    #
    def process_raw_reads distributions
      status "filtering unaligned fastq.gz files"
      wait_on_task = nil
     
      fastq_path = @flowcell.paths.unaligned_dir
      puts fastq_path
      fastq_files = Dir.glob(File,join(fastq_path, "**","*.fastq.gz"))
      
      fastq_file_data = get_file_data fastq_files, "\.fastq\.gz"
      puts "#{fastq_file_data}"
    
    
    #  fastq_groups = groups_fastq_files(@flowcell.paths.unaligned_project_dir, @flowcell.paths.fastq_combine_dir)
    
    #  fastq_groups = group_files fastq_file_data, output_path, options
      
      
      status "filtering unaligned fastq.gz files"
     # unless @options[:only_distribute]
      #  filter_task_name = parallel_filter_fastq_files("unaligned", fastq_groups, @flowcell.paths.fastq_filter_dir, wait_on_task)
       # wait_on_task = filter_task_name
      #end
      #wait_on_task

      #unless @options[:no_distribute] or distributions.empty?
       # status "distributing unaligned fastq.gz files"
        #distribute_task_name = parallel_distribute_files("unaligned", fastq_groups, distributions, wait_on_task)
        #wait_on_task = distribute_task_name
      #end
     
      wait_on_task
    end

    def process_undetermined_reads distributions, wait
      status "process undetermined unaligned reads"
      starting_path = @flowcell.paths.unaligned_undetermined_dir
      output_path = @flowcell.paths.unaligned_undetermined_combine_dir
      options = {:prefix => "s_", :suffix => ".fastq.gz", :exclude_undetermined => false}
      wait_on_task = wait

      fastq_file_groups = group_fastq_files starting_path, output_path, options

      unless @options[:only_distribute]
        cat_task_name = parallel_cat_files "undetermined", fastq_file_groups, wait_on_task
        wait_on_task = cat_task_name
      end

      unless @options[:no_distribute]
        status "distributing unaligned undetermined fastq.gz files"
        distribute_task_name = parallel_distribute_files("undetermined", fastq_file_groups, distributions, wait_on_task)
        wait_on_task = distribute_task_name
      end

      wait_on_task
    end


    def process_custom_barcode_reads distributions, wait_on_task
      status "processing custom barcode reads"
      fastq_groups = group_fastq_files(@flowcell.paths.unaligned_project_dir,
                                       @flowcell.paths.fastq_combine_dir)
      # custom_barcode_files = split_custom_barcodes fastq_groups
      # distribute_files(custom_barcode_files, distributions) unless custom_barcode_files.empty?
    end

    #
    # Executes commands related to export files, including renaming them
    # and distributing them to project directories.
    #
    def run_aligned distributions, wait_on_task
      status "processing export files"
      aligned_project_dir = get_aligned_project_dir
      export_groups = group_export_files(aligned_project_dir,
                                         @flowcell.paths.eland_combine_dir)
      unless @options[:only_distribute]
        cat_task_id = parallel_cat_files("aligned", export_groups, wait_on_task)
        wait_on_task = cat_task_id
      end

      unless @options[:no_distribute] or distributions.empty?
        status "distributing export files"
        parallel_task_id = parallel_distribute_files("aligned", export_groups, distributions, wait_on_task)
        wait_on_task = parallel_task_id
      end
      wait_on_task
    end

    def get_aligned_project_dir
      project_dir = ""
      dirs = @flowcell.paths.aligned_project_dirs
      if dirs.size == 0
        puts "ERROR: No Aligned Project dir found for #{@flowcell.id}"
        raise "NO ALIGNED PROJECT DIR"
      elsif dirs.size == 1
        project_dir = dirs.shift
      else
        projects_with_samples = []
        dirs.each do |dir|
          sample_dirs = Dir.glob(File.join(dir, "Sample_*"))
          if sample_dirs.size > 0
            projects_with_samples << dir
          end
        end

        if projects_with_samples.size == 0
          puts "ERROR: No Sample Directories Found in:"
          puts dirs.join(", ")
          raise "NO SAMPLES IN PROJECT DIR"
        elsif projects_with_samples.size == 1
          project_dir = projects_with_samples.shift
          puts "WARNING: All Sample Dirs in #{project_dir}"
        else
          final_project_dir = File.join(@flowcell.paths.aligned_dir, "Project_#{@flowcell.id}")
          puts "WARNING: Combining export files in #{final_project_dir}"
          system("mkdir -p #{final_project_dir}")
          projects_with_samples.each do |sample_project|
            sample_dirs = Dir.glob(File.join(sample_project, "Sample_*"))
            sample_dirs.each do |sample_dir|
              system("mv #{sample_dir} #{final_project_dir}")
            end
          end
          project_dir = final_project_dir
        end
        puts project_dir
        project_dir
      end

    end

    

    #
    # Sends flowcell stats to Lims
    #
    def upload_lims dependency
      status "uploading to lims"

      task_name = submit_one("lims", "lims_upload", dependency, "#{@flowcell.id}")
    end

    #
    # Mark flowcell as complete in LIMs
    #
    def complete_lims dependency, wait_time
      status "completing lims"

      task_name = submit_one("lims", "lims_complete", dependency, "#{@flowcell.id} #{wait_time}")
    end

    #
    # Executes all functionality related to splitting lanes with customm
    # barcodes into separate fastq.gz files. Should be executed before
    # running fastqc to get separate results for each barcoded sample.
    #
    def split_custom_barcodes groups
      custom_barcode_data = []
      groups.each do |sample_data|
        barcode_file_path = @flowcell.paths.custom_barcode_path(sample_data[:lane])
        if File.exists?(barcode_file_path)
          orginal_fastq_path = sample_data[:path]
          fastq_base_dir = File.dirname(orginal_fastq_path)
          file_prefix = File.join(fastq_base_dir, "s_#{sample_data[:lane]}_#{sample_data[:read]}_")
          file_suffix = ".fastq"

          command = "zcat #{orginal_fastq_path} |"
          command += " fastx_barcode_splitter.pl --bcfile #{barcode_file_path}"
          command += " --bol --prefix \"#{file_prefix}\""
          command += " --suffix \"#{file_suffix}\""
          command += " > #{@flowcell.paths.custom_barcode_path_out(sample_data[:lane])} 2>&1"
          execute command

          unmatched = Dir.glob("#{file_prefix}unmatched#{file_suffix}")
          unmatched.each do |unmatched_filename|
            undetermined_filename = "#{file_prefix}Undetermined#{file_suffix}"
            execute "mv #{unmatched_filename} #{undetermined_filename}"
          end

          uncompressed_fastq_files = Dir.glob("#{file_prefix}*#{file_suffix}")
          compressed_fastq_files = []
          uncompressed_fastq_files.each do |uncompressed_fastq_file|
            execute "gzip -f #{uncompressed_fastq_file}"
            compressed_fastq_files << uncompressed_fastq_file + ".gz"
          end

          compressed_fastq_files.each do |barcode_file_path|
            barcode_file_name = File.basename(barcode_file_path)
            custom_barcode_hash = {:lane => sample_data[:lane], :read => sample_data[:read],
                                   :path => barcode_file_path, :group_name => barcode_file_name}
            custom_barcode_data << custom_barcode_hash
          end
        end
      end
      custom_barcode_data
    end

    

    #
    # Collects the stats files needed and distributes them
    #
    def create_custom_stats_files
      new_stats_dir_path = @flowcell.paths.custom_stats_dir
      execute "mkdir -p #{new_stats_dir_path}"

      ivc_file = File.join(@flowcell.paths.unaligned_stats_dir, "IVC.htm")
      convert_to_pdf ivc_file
      ivc_pdf = find_files_in "IVC.pdf", @flowcell.paths.unaligned_stats_dir
      copy_files ivc_pdf, new_stats_dir_path

      demultiplex_stats_file = find_files_in "Demultiplex_Stats.htm", @flowcell.paths.unaligned_stats_dir
      copy_files demultiplex_stats_file, new_stats_dir_path

      stats_files = ["Barcode_Lane_Summary.htm", "Sample_Summary.htm"]
      if @flowcell.paths.aligned_project_dir and File.exists?(@flowcell.paths.aligned_project_dir)
        summary_files = find_files_in(stats_files, @flowcell.paths.aligned_stats_dir)
        copy_files summary_files, new_stats_dir_path
      end
    end

    def distribute_custom_stats_files distribution
      status "distributing aligned stats files"
      distribute_to_unique distribution, @flowcell.paths.custom_stats_dir
    end

    #
    # Helper method to copy files from one location to another
    #
    def copy_files file_paths, destination_path
      files = [file_paths].flatten
      files.each do |file_path|
        execute "cp #{file_path} #{destination_path}"
      end
    end

    #
    # Helper method to return an array of files that match
    # a particular pattern and are rooted in one or more places.
    # Both inputs are arrays, but can also be individual strings.
    #
    def find_files_in file_matches, root_paths
      root_paths = [root_paths].flatten.compact
      file_matches = [file_matches].flatten.compact
      returned_paths = []
      root_paths.each do |root_path|
        matched_paths = file_matches.collect do |file|
          matched_files = Dir.glob(File.join(root_path, file))
          matched_files.size > 0 ? matched_files[0] : nil
        end
        matched_paths.compact
        returned_paths.concat matched_paths
      end
      returned_paths
    end

    #
    # Helper method to call wkhtmltopdf on an input file.
    # No error checking is done.
    #
    def convert_to_pdf input_file
      if check_exists(input_file)
        output_file = input_file.split(".")[0..-2].join(".") + ".pdf"
        execute "wkhtmltopdf #{input_file} #{output_file}"
      end
    end

    #
    # Given a set of file groups and an array of distribution paths,
    # this method copies the appropriate files to the appropriate
    # project directories.
    # By appropriate, we mean that the lane in the file group matches
    # the lane indicated in the distributions.
    #
    def distribute_files file_groups, distributions
      distributions.each do |distribution|
        log "# Creating directory #{distribution[:path]}"
        execute "mkdir -p #{distribution[:path]}"

        distribution_groups = file_groups.select {|g| g[:lane].to_i == distribution[:lane].to_i}
        log "# Found #{distribution_groups.size} groups"
        Parallel.each(distribution_groups, :in_processes => DISTRIBUTE_PROCESSES) do |group|
          present = check_exists(group[:path])
          if present
            command = "cp #{group[:path]} #{distribution[:path]}"
            execute command
          end
        end
      end
    end

   
    

    #
    # Gets grouping data for fastq.gz files
    #
    def group_fastq_files starting_path, output_path, options = {:prefix => "s_", :suffix => ".fastq.gz", :exclude_undetermined => true}
      execute "mkdir -p #{output_path}"
      fastq_groups = []

      fastq_files = Dir.glob(File.join(starting_path, "**", "*.fastq.gz"))
      if fastq_files.empty?
        log "# ERROR: no fastq files found in #{starting_path}" if fastq_files.empty?
      else
        log "# #{fastq_files.size} fastq files found in #{starting_path}"
        fastq_file_data = get_file_data fastq_files, "\.fastq\.gz"
        fastq_groups = group_files fastq_file_data, output_path, options
      end
      fastq_groups
    end


    #
    # Gets grouping data for export files
    #
    def group_export_files starting_path, output_path
      execute "mkdir -p #{output_path}"

      export_files = Dir.glob(File.join(starting_path, "**", "*_export.txt.gz"))
      raise "ERROR: no export files found in #{starting_path}" if export_files.empty?
      log "# #{export_files.size} export files found in #{starting_path}"

      export_file_data = get_file_data export_files, "_export\.txt\.gz"
      options = {:prefix => "s_", :suffix => "_export.txt.gz", :exclude_undetermined => true}
      export_groups = group_files export_file_data, output_path, options
      export_groups
    end

    
    #
    # Actually combines the related fastq files
    # using cat.
    #
    def cat_files file_groups
      file_groups.each do |group|
        check_exists(group[:paths])
        # this is the Illumina recommended approach to combining these fastq files.
        # See the Casava 1.8 Users Guide for proof
        files_list = group[:paths].join(" ")
        command = "cat #{files_list} > #{group[:path]}"
        execute command
      end
    end

    def parallel_cat_files prefix, file_groups, dependency = nil
      database = []
      file_groups.each do |group|
        check_exists(group[:paths])
        files_list = group[:paths].join(" ")
        entry = {}
        entry[:files] = files_list
        entry[:destination] = group[:path]
        database << entry
      end
      task_name = submit_parallel(prefix, "cat_files", database, dependency)
      task_name
    end



    

    #
    # Method to strip out reads in fastq.gz files that do not
    # pass filter. Filtered files are copied to the :filter_path
    # in the groups hash.
    #
    def filter_fastq_files fastq_groups, output_path

      log "# Creating path: #{output_path}"
      execute "mkdir -p #{output_path}"

      fastq_groups.each do |group|
        command = "zcat #{group[:path]} | #{FILTER_SCRIPT} | gzip -c > #{group[:filter_path]}"
        execute command
      end
    end

    def parallel_filter_fastq_files prefix, fastq_groups, output_path, dependency
      log "# Creating path: #{output_path}"
      execute "mkdir -p #{output_path}"

      database = []
      fastq_groups.each do |group|
        entry = {:input => group[:path], :filter => FILTER_SCRIPT, :output => group[:filter_path]}
        database << entry
      end
      task_name = submit_parallel(prefix, "filter_fastq", database, dependency)
      task_name
    end

    #
    # Returns an array of hashes, one for each
    # new combined fastq file to be created
    # Each hash will have the name of the
    # combined fastq file and an Array of
    # paths that the group contains
    #
    def group_files file_data, output_path, options = {:prefix => "s_", :suffix => ".fastq.gz", :exclude_undetermined => true}
      groups = {}
      file_data.each do |data|
        if data[:barcode] == "Undetermined" and options[:exclude_undetermined]
          log "# Undetermined sample lane: #{data[:lane]} - name: #{data[:sample_name]}. Skipping"
          next
        end

        group_key = name_for_data data, options

        if groups.include? group_key
          if groups[group_key][:sample_name] != data[:sample_name]
            raise "ERROR: sample names not matching #{group_key} - #{data[:path]}"
          end
          if groups[group_key][:lane] != data[:lane]
            raise "ERROR: lanes not matching #{group_key} - #{data[:path]}"
          end
          groups[group_key][:files] << data
        else
          group_path = File.join(output_path, group_key)
          groups[group_key] = {:group_name => group_key,
                               :path => group_path,
                               :sample_name => data[:sample_name],
                               :read => data[:read],
                               :lane => data[:lane],
                               :files => [data]
          }
        end
      end

      # sort based on read set
      groups.each do |key, group|
        group[:files] = group[:files].sort {|x,y| x[:set] <=> y[:set]}
        group[:paths] = group[:files].collect {|data| data[:path]}
      end
      groups.values
    end

    def name_for_data data, options = {:prefix => "s_", :suffix => ".fastq.gz"}
      "#{options[:prefix]}#{data[:lane]}_#{data[:read]}_#{data[:barcode]}#{options[:suffix]}"
    end


    #
    # Returns Array of hashes for files in input
    # Hash includes sample_name, barcode, lane,
    # basename, and full path
    #
    def get_file_data files, suffix_pattern = "\.fastq\.gz"
      files = [files].flatten

      $NAME_PATTERN = /(.*)_([ATCGN-]+|NoIndex|Undetermined)_L(\d{3})_R(\d)_(\d{3})#{suffix_pattern}/
      # 1_ACTTGA_ACTTGA_L001_R1_002.fastq.gz
      # $1 = "1_ACTTGA"
      # $2 = "ACTTGA"
      # $3 = "001"
      # $4 = "1"
      # $5 = "002"

      file_data = files.collect do |file|
        base_name = File.basename(file)
        match = base_name =~ $NAME_PATTERN
        raise "ERROR: #{file} does not match expected file name pattern" unless match
        data = {:name => base_name, :path => file,
                :sample_name => $1, :barcode => $2,
                :lane => $3.to_i, :read => $4.to_i, :set => $5.to_i}
        data
      end
      file_data
    end
=end
  end
end
