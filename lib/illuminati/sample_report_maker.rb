require 'illuminati/flowcell_record'
require 'illuminati/tab_file_parser'
require 'illuminati/html_parser'

module Illuminati
  #
  # Aggregates all the crap necessary to fill out the simplest of all csv files.
  # Responsible for generating string to create Sample_Report.csv from.
  #
  class SampleReportMaker
    DATA_NAMES = [:output, :lane, :name, :illumina, :custom, :read, :genome]

    #
    # Makes the SampleReport string. Not actually outputing it to file.
    # Depends on FlowcellRecord, TabFileParser, and HtmlParser for most of
    # the work required.
    #
    # Most of the data comes from the FlowcellRecord. Currently, the only value
    # missing is the number of reads. This is contained either in the Demultiplex_Stats.htm
    # file for regular lanes or TruSeq lanes and in the fastx_barcode_splitter output
    # for custom barcoded reads... Fun stuff.
    #
    def self.make flowcell
      @flowcell = flowcell
      demultiplex_filename = File.join(@flowcell.paths.unaligned_stats_dir, "Demultiplex_Stats.htm")
      sample_report_filename = File.join(@flowcell.paths.aligned_stats_dir, "Sample_Summary.htm")
      html_parser = HtmlParser.new
      @demultiplex_data = html_parser.table_data(demultiplex_filename)[0]
      @sample_report_data = html_parser.table_data(sample_report_filename)
      @tab_parser = TabFileParser.new

      sample_report = ["output", "lane", "sample name", "illumina index",
                       "custom barcode", "read", "reference"].join(",")
      sample_report += ","
      sample_report += ["total reads", "pass filter reads", "pass filter percent"].join(",")
      sample_report += ["genome", "align percent", "analysis type", "read length"].join(",")
      sample_report += "\n"

      @flowcell.each_sample_with_lane do |sample, lane|
        read_data = data_for sample
        read_data.each do |sample_read_data|
          sample_read_string = sample_read_data.join(",")
          sample_report += sample_read_string
          sample_report += "\n"
        end
      end
      sample_report
    end

    #
    # Returns all the data for a single sample.
    # Deals with paired_end data, custom barcodes,
    # Illumina indexed barcodes and non-multiplexed lanes.
    #
    def self.data_for sample
      all_read_data = []
      sample_datas = sample.sample_report_data
      demultiplex_data = []

      sample_datas.each do |sample_data|
        data = DATA_NAMES.collect {|key| sample_data[key]}
        demultiplex_data = data_from_custom_barcode sample
        if demultiplex_data.empty?
          demultiplex_data = data_from_demultiplex_sample_data sample
        end

        data << demultiplex_data
        data.flatten!
        all_read_data << data
      end
      all_read_data
    end

    #
    # Returns the number of reads count from the Demultiplex_Stats.htm
    # file for a particular sample.
    #
    # Return value is a string. nil is returned if count cannot be found.
    #
    def self.data_from_demultiplex_sample_data sample
      count = nil
      demultiplex_sample_data = demultiplex_data_for_sample sample, @demultiplex_data
      data = []
      if !demultiplex_sample_data
        puts "ERROR: sample report maker cannot find demultiplex data for #{sample.id}"
      else
        count = demultiplex_sample_data["# Reads"]
        count.gsub!(",","")
        data << count
        percent = demultiplex_sample_data["% PF"]
        data << percent
        count_num = count.to_f
        percent_num = percent.to_f
        pass_filter_count = (count_num * (percent_num / 100.0)).round
        data << pass_filter_count.to_s
      end
      data
    end

    #
    # Returns count value from custom barcode output for a particular sample.
    # Return value is a string. nil is returned if count cannot be found or
    # if no custom barcodde output file is present.
    #
    def self.data_from_custom_barcode sample
      barcode_filename = @flowcell.paths.custom_barcode_path_out(sample.lane.to_i)
      data = []
      if File.exists? barcode_filename
        count = nil
        all_barcode_data = @tab_parser.parse(barcode_filename)
        barcode_data = barcode_data_for_sample sample, all_barcode_data
        if !barcode_data
          puts "ERROR: sample report maker cannot find barcode data for #{sample.id} #{sample.barcode}"
        else
          count = barcode_data["Count"]
          data << count
          # custom barcode doesn't have other info
          data << 0 << 0
        end
      end
      data
    end

    #
    # Returns the barcode data for a particular sample from
    # all possible barcode data. Used by custom barcode count finder.
    #
    def self.barcode_data_for_sample sample, barcoded_data
      barcoded_data.each do |barcode_line|
        if barcode_line["Barcode"] == sample.custom_barcode
          return barcode_line
        end
      end
      nil
    end

    #
    # Returns data from Demultiplex_Stats.htm for a particular sample.
    # Sample matching is done using the Sample ID.
    #
    def self.demultiplex_data_for_sample sample, demultiplex_data
      demultiplex_data.each do |demultiplex_sample|
        if demultiplex_sample["Sample ID"] == sample.id
          return demultiplex_sample
        end
      end
      nil
    end
  end
end

