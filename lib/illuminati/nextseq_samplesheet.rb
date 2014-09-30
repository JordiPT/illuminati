
#$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
#
#require 'bundler/setup'

#require 'illuminati'
require 'illuminati/external_data_lims'


class NextSeqSampleSheet
    # Generate a sample sheet for NextSeq runs compatible with bcl2fastq2
    
    # THe order of samples is according to LIMS library IDs
    
    ## [Header],,,,
    ## Investigator Name,Isabelle,,,
    ## Project Name,Kidney23,,,
    ## Experiment Name,Sample 23,,,
    ## Date,11/27/2013,,,
    ## Workflow,GenerateFASTQ,,,
    ## ,,,,
    ## [Settings],,,,
    ## MaskAdapter,CGCGTATACGCGTATA,,,
    ## TrimAdapter,GCGCATATGCGCATAT,,,
    ## ,,,,
    ## [Data],,,,
    ## SampleID,SampleName,index,index2
    ## AA,AA,AAAAAAAA,AAAAAAAA
    ## CC,CC,CCCCCCCC,CCCCCCCC
    ## GG,GG,GGGGGGGG,GGGGGGGG
    ## TT,TT,TTTTTTTT,TTTTTTTT
    ## XX,XX,ACGTACGT,ACGTACGT 
    
    
    # Illumnia replaces '_' with '-' in bcl2fastq names, preempt this annoyance
    JOIN_CHAR = '-'
    
    def initialize options, samples
      @options = options
      @orig_samples = samples
      if samples.first[:protocol] == 'eland_pair' 
        @read_numbers = [1,2]
      else
        @read_numbers = [1]
      end
      
      @lib_record = []
      @libs_group = samples.group_by{|x| x[:lib_id]}
      lib_ids = @libs_group.keys()
      #puts lib_ids
      @libs = @libs_group.collect{|k,a| a.first}
      
      #puts "Lims sample count: #{@orig_samples.length}  Actual sample count: #{@libs.length}"
      
      #puts self.generate_sample_sheet
      
      @sample_sheet_file = @options[:sample_sheet_file]
      
      # The sample sheet must be located at the top level of the run folder.
      @output_dir = @options[:runfolder_dir]
      
      @sample_sheet = self.generate_sample_sheet
      Dir.chdir(@output_dir)
      File.open(@sample_sheet_file, 'w') do |f_ss|  
        f_ss.puts @sample_sheet
      end
      @sample_sheet_full_path = File.join(@output_dir, @sample_sheet_file)
      
      self.fastq_names
      
    end
    
    def build_header_block
      return "[Header],,,,"
    end
    
    def build_settings_block
      # Not implemented
    end
    
    def build_data_block
      data_block = ["[Data],,,,\nSampleID,SampleName,index,index2"]
      for s in @libs do
        sample_id   = s[:lib_id]
        sample_name = [s[:lib_id],s[:barcode]].join(JOIN_CHAR)
        # temp, external_data_lims joins barcodes, need to split, if required
        if s[:barcode].include? "-"
          barcodes = split('-')
          barcode1 = barcodes[0]
          barcode2 = barcodes[1]
        else
          barcode1 = s[:barcode]
          barcode2 = ""
        end
        @lib_record << {:sample_id=> sample_id, :sample_name=>sample_name, :barcode1=>barcode1, :barcode2=>barcode2, :genome=>s[:genome]}
        sample_record = [sample_id,sample_name,barcode1,barcode2].join(",")
        data_block << sample_record
      end
      data_block.join("\n")
    end
    
    def generate_sample_sheet
      # only the data block is generate
      return [self.build_header_block, self.build_data_block].join("\n")
    end
    
    def get_libs
      @libs
    end
    
    def fastq_names
      # create a mapping for lib_ids to fastq files
      # format L9917-CGATGT_S2_L001_R1_001
      # lims_data["samples"].each do |lims_sample_data|
      fastq_ext = ".fastq.gz"
      fastq_names = []
      fastq_records = []
      fastq_counts = 0
      @lib_record.each_index do |index|
        lib_entry = []
        entry = @lib_record[index]
        sample_number = index + 1
        for lane_index in [1,2,3,4] #config.nextseq_lanes
          lane_number_padded = lane_index.to_s.rjust(3, '0')
          fastq_record = {} # handle paired-end samples using hash
          for read_number in @read_numbers
            fastq_name = "#{entry[:sample_name]}_S#{sample_number}_L#{lane_number_padded}_R#{read_number}_001#{fastq_ext}"
            fastq_record[read_number] = fastq_name
            fastq_counts = fastq_counts + 1
          end
          lib_entry << fastq_record
        end  
        entry[:fastq] = lib_entry
        fastq_names << lib_entry
        fastq_records << entry
      end
      @fastq_names = fastq_names
      @fastq_records = fastq_records
      puts "FASTQ counts: #{fastq_counts}"
    end
    
    def get_fastq_names
      @fastq_names
    end
    
    def get_fastq_records
      @fastq_records
    end
    
end

  
  