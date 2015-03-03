
module Illuminati
	class NextSeqPostrunner 
		ALL_STEPS = %w{setup alianed unmapped fastqc aligned stats report qcdata lims}
		DEFAULT_STEPS = %w{setup unaligned fastqc aligned stats report}

		ALIGNMENT_FILE_MATCHES = ["*.bam"]
		STATS_FILE_MATCHES = []

		def intitialize flowcell, options = {}
			options = {:test => false, :steps=> ALL_STEPS}.merge(options)

			options[:steps].each do |step|
				valid = true
				unless ALL_STEPS.include? step
					puts "ERROR: invalid step: #{step}"
					valid = false
				end

				if !valid
					puts "Valid steps: #{ALL_STEPS.join(", ")}"
					raise "Invalid step"
				end
			end

			#
			# Main entry point into PostRunner. Starts post run process and executes all
			# required steps to getting data and files in to the way we want them.

			def run
				start_flowcell
				distributions = []


				unless @options[:no_distribute]
					distributions = @flowcell.external_data.distributions_for @flowcell.id 
				end

				steps = @options[:steps]
				logm "running steps: #{steps.join(", ")}"

				if steps.include? "setup"
					copy_sample_sheet
				end

				if steps.include? "unaligned"
					#process_unaligned_reads distributions
				end

				if steps.include?


			end

			def logm message
				log "# #{message}"
				SolexaLogger.log(@flowcell.paths.id, message) unless @options[:test]
			end

			def copy_sample_sheet
				source = File.join(@flowcell.paths.base_dir, "SampleSheet.csv")
				destination = File.join(@flowcell.paths.unaligned_dir, "SampleSheet.csv")
				if !File.exists? source
					puts "ERROR: cannot find SampleSheet at: #{source}"
				end

				execute("cp #{source} #{destination}")
			end

			def process_unaligned_reads distributions
				status "processing unaligned"
				steps = @options[:steps]
				fastq_groups = group_fastq_files(@flowcell.paths.unalinged_project_dir,
					                               @flowcell.paths.fastq_combine_dir)
				#unless @options[:only_distribute]
				#	cat files fastq_groups
				#end

				###### LAST STOP

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
      # Gets grouping data for fastq.gz files
      #
      def group_fastq_files starting_path, output_path, options = {:prefix => "L", :suffix => ".fastq.gz", :exclude_undetermined => true}
        execute "mkdir -p #{output_path}"
        fastq_groups = []
  
        fastq_files = Dir.glob(File.join(starting_path, fastq_search_path))
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



      #
      # Returns an array of hashes, one for each
      # new combined fastq file to be created
      # Each hash will have the name of the
      # combined fastq file and an Array of
      # paths that the group contains
      #
      def group_files file_data, output_path, options = {:prefix => "L", :suffix => ".fastq.gz", :exclude_undetermined => true}
				# alternatively inherit the parent class and call super???? 
				# super 
				#      	
        groups = {}
        file_data.each do |data|
          if data[:barcode] == "Undetermined" and options[:exclude_undetermined]
            log "# Undetermined sample lane: #{data[:lane]} - name: #{data[:sample_name]}. Skipping"
            next
          end
  
          group_key = name_for_data data, options
  
          if groups.include? group_key
            if groups[group_key][:sample_name] != data[:sample_name]
              raise "ERROR: sample names not matching #{group_key} - #{data[:path]}:#{data[:sample_name]}vs#{groups[group_key][:sample_name]}"
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



	end
end