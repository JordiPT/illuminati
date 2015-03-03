#! /usr/bin/env ruby



$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'illuminati'


if __FILE__ == $0
  flowcell_id = ARGV[0]
  type = ARGV[1]
  #puts flowcell_id
  if flowcell_id
    flowcell = Illuminati::FlowcellPaths.new flowcell_id
    fastq_hash = Hash.new
    #puts flowcell.base_dir
    fastq_size = ""
    if type=="nextseq"
      fastq_files = Dir.glob(File.join(flowcell.unaligned_dir, "*.fastq.gz"))
      system "cd #{flowcell.unaligned_dir}"
      #puts fastq_files
      $FASTQ_PATTERN = /(.*)Unaligned\/(.*)_S(\d)_L(\d{3})_R(\d)_(.*)/

      fastq_files.each do |x|

        result = `du -b #{x}`
        fastq_array = result.split("\t")
        match = fastq_array[1] =~ $FASTQ_PATTERN

        if ($2 == "Undetermined")
          lane = "Undetermined_#{$4.to_i}"
        else
          lane = "Regular_#{$4.to_i}"
        end
        size = fastq_array[0].to_i

        if(fastq_hash.has_key?(lane))
          temp = fastq_hash[lane].to_i
          fastq_hash[lane] = temp+size
        else
          fastq_hash[lane] = size
        end
      end

    elsif type=="hiseq"
      fastq_files_regular = Dir.glob(File.join(flowcell.fastq_combine_dir, "*.fastq.gz"))
      fastq_files_undertermined = Dir.glob(File.join(flowcell.unaligned_undetermined_combine_dir, "*.fastq.gz"))
      $FASTQ_PATTERN = /s_(\d)_(\d)_(.*)/

      system "cd #{flowcell.fastq_combine_dir}"

      fastq_files_regular.each do |x|

        result = `du -b #{x}`
        fastq_array = result.split("\t")
        match = fastq_array[1] =~ $FASTQ_PATTERN
        lane = "Regular_#{$1.to_i}"
        size = fastq_array[0].to_i

        if(fastq_hash.has_key?(lane))
          temp = fastq_hash[lane].to_i
          fastq_hash[lane] = temp+size
        else
          fastq_hash[lane] = size
        end
      end

      system "cd #{flowcell.unaligned_undetermined_combine_dir}"

      fastq_files_undertermined.each do |x|

        result = `du -b #{x}`
        fastq_array = result.split("\t")
        match = fastq_array[1] =~ $FASTQ_PATTERN
        lane = "Undetermined_#{$1.to_i}"
        size = fastq_array[0].to_i

        if(fastq_hash.has_key?(lane))
          temp = fastq_hash[lane].to_i
          fastq_hash[lane] = temp+size
        else
          fastq_hash[lane] = size
        end
      end
    end


    fastq_summary = File.join(flowcell.base_dir,"fastq_stat_#{flowcell_id}.txt")
    fastq_barplot = File.join(flowcell.base_dir,"fastq_stat_#{flowcell_id}.jpeg")

    File.open(fastq_summary, 'w') do |file|
      fastq_hash.each do |x,y|
        group = x.split("_")
        file.puts "#{group[0]}:#{group[1]}:#{y}"
      end
    end

    system "Rscript barplot.r #{fastq_summary} #{fastq_barplot}"
    Illuminati::Emailer.email "fastq files stats: #{fastq_barplot}" , fastq_barplot
  else
    puts "ERROR: No flowcell_id"
  end
end


