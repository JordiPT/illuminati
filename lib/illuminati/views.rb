require 'erb'

module Illuminati
  SAMTOOLS_GENOMES = {'smed' => 'smed31/smed.fa', 'smed31' => 'smed31/smed.fa', 'stella' => 'nemve1/nemve1.fa', 'nemve1' => 'nemve1/nemve1.fa'}
  #
  # Responsible for organizing flowcell record into output used to generate a config.txt file for
  # CASAVA 1.8 ELANDv2e alignment.
  #
  # Uses config.txt.erb in assests directory for most of the formating of the config.txt file.
  #
  class ConfigFileView
    # Location of the erb template file to use to build config.txt
    CONFIG_TEMPLATE_PATH = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "assests", "config.txt.erb"))
    attr_accessor :lanes, :input_dir, :flowcell_id

    #
    # Create new instance of view.
    #
    # == Parameters
    # flowcell_record::
    #   Instance of FlowcellRecord to create a config.txt file from.
    def initialize flowcell_record, lanes = [1,2,3,4,5,6,7,8]
      @lanes = convert_lanes(filter_lanes(flowcell_record, lanes))
      @input_dir = flowcell_record.paths.unaligned_dir
    end

    #
    # Outputs flowcell record into config.txt format.
    #
    # == Returns:
    # Doesn't actually write to file, but instead returns string representation of config.txt.
    # This was done mostly as a convience during testing.
    #
    def write
      template = ERB.new File.new(CONFIG_TEMPLATE_PATH).read, nil, "%<>"
      output = template.result(binding)
    end

    #
    # Removes lanes that we don't want to include in the alignment
    #
    # == Parameters:
    #  flowcell_record::
    #     FlowcellRecord to look at
    #
    #  keep_lanes::
    #     Array of lanes to align
    #
    # == Returns:
    # Array of lane hashes
    def filter_lanes flowcell_record, keep_lanes
      lane_data = []
      flowcell_record.lanes.each do |lane|
        if !keep_lanes.include?(lane.number.to_i)
          next
        end
        lane_data << lane.to_a
      end
      lane_data
    end

    # input: array of lane data
    # output: simplified form for config.txt file
    def convert_lanes lane_data

      simple_out = []

      # lane is an array of sample hashes
      lane_data.each do |lane|
        simple_lane = {}
        simple_lane[:lane] = lane[0][:lane]
        simple_lane[:protocol] = lane[0][:protocol]
        genomes = lane.collect {|s| s[:genome]}.uniq

        simple_lane[:genomes] = []
        genomes.each do |genome|
          if genome.strip.empty?
            next
          end
          if genome.strip.downcase == 'none'
            next
          end
          simple_genome = {}
          simple_genome[:name] = genome
          simple_genome[:type] = SAMTOOLS_GENOMES.keys.include?(genome) ? "SAMTOOLS_GENOME" : "ELAND_GENOME"
          simple_genome[:path] = SAMTOOLS_GENOMES.keys.include?(genome) ? "#{GENOMES_ROOT}/#{SAMTOOLS_GENOMES[genome]}" : "#{GENOMES_ROOT}/#{genome}"

          simple_lane[:genomes] << simple_genome
        end

        simple_lane[:genome] = genomes[0]


        simple_out << simple_lane
      end

      simple_out
    end

    #
    # Groups similar lanes of flowcell record to make config.txt output shorter.
    # We try to determine which lanes have the same parameters and then group them
    # for outputting to config.txt. This step isn't required, but results in config.txt files
    # that are much shorter and more concise.
    #
    # == Parameters:
    # flowcell_record::
    #   FlowcellRecord to look at.
    #
    # == Returns:
    # Array of lane data arrays. Each lane data array will have the values needed to
    # generate config.txt contents for one or more lanes. See the config.txt.erb file
    # for details on how these are used.
    #
    #
    def squash_lanes flowcell_record, keep_lanes
      squashed_lane_data = []
      current_lane_index = 0
      squashed_lane_data << flowcell_record.lanes[current_lane_index].to_h
      flowcell_record.lanes[1..-1].each do |lane|
        if !keep_lanes.include?(lane.number.to_i)
          # puts "skipping #{lane.number}"
          current_lane_index += 1
          next
        end
        current_lane = squashed_lane_data[current_lane_index]
        if flowcell_record.lanes[current_lane_index].equal(lane)
          # puts "adding #{lane.number} to #{current_lane_index}"
          current_lane[:lane] = current_lane[:lane].to_s << lane.number.to_s
          squashed_lane_data[current_lane_index] = current_lane
        else
          # puts "new: #{lane.number}"
          puts "#{lane.to_h.inspect}"
          squashed_lane_data << lane.to_h
          current_lane_index += 1
        end
      end
      # puts squashed_lane_data.inspect
      squashed_lane_data
    end
  end
end

module Illuminati
  #
  # SampleSheet.csv is required by CASAVA 1.8 to perform demultiplexing and alignment.
  # This view is responsible for generating this csv file content from a FlowcellRecord.
  #
  class SampleSheetView
    #
    # Create new instance of this view.
    #
    # == Parameters:
    # flowcell_record::
    #   the FlowcellRecord to generate a SampleSheet.csv from.
    def initialize flowcell_record, lanes = [1,2,3,4,5,6,7,8]
      @flowcell = flowcell_record
      @lanes = lanes

    end

    #
    # Returns FlowcellRecord data in SampleSheet.csv form. Does not
    # actually write the contents to file.
    #
    # == Returns:
    # String which can be saved as SampleSheet.csv and contains all the
    # data required for all lanes / samples. This data is acquired from
    # the FlowcellRecord which in turn acquires it from the LIMS system and
    # the SampleMultiplex.csv file (if present).
    #
    def write
      sample_sheet =  ["fcid", "lane", "sampleid",
                       "sampleref", "index", "description",
                       "control", "recipe", "operator",
                       "sampleproject"].join(",")
      sample_sheet += "\n"

      #lanes_added used to exclude lanes with custom barcode
      #but no illumina barcode
      lanes_added = []
      @flowcell.each_sample_with_lane do |sample, lane|
        next unless @lanes.include?(lane.number.to_i)
        data = []
        if !lanes_added.include?(sample.lane) or (sample.illumina_barcode and !sample.illumina_barcode.empty?)
          data << @flowcell.id << sample.lane << sample.id
          # WARNING:
          # stupid hack to switch barcode delimiters. probably a terrible idea
          data << sample.genome << sample.illumina_barcode.gsub("_", "-")
          data << sample.description << sample.control
          data << "see lims" << "see lims"
          data << @flowcell.id
          lanes_added << sample.lane
          sample_sheet += data.join(",")
          sample_sheet += "\n"
        end
      end
      sample_sheet
    end
  end
end
