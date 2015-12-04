#! /usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'illuminati'


if __FILE__ == $0
  flowcell_id = ARGV[0]
  type = ARGV[1]
  flag = ARGV[2]

  #puts flowcell_id
  if flowcell_id
    flowcell = Illuminati::FlowcellPaths.new flowcell_id
    fastq_hash = Hash.new
    barcode_hash = Hash.new
    #puts flowcell.base_dir
    fastq_size = ""
    if type=="nextseq"
      fastq_files = Dir.glob(File.join(flowcell.unaligned_dir, "*.fastq.gz"))
      system "cd #{flowcell.unaligned_dir}"
      #puts fastq_files

      if(flag=="rerun")
        $FASTQ_PATTERN = /(n)_(\d)_(\d)_([ATCGN-]+|NoIndex|Undetermined)(.*)/
      else
        $FASTQ_PATTERN = /(.*)Unaligned\/(.*)_S(.*)_L(\d{3})_R(\d)_(.*)/
      end

      fastq_files.each do |x|

        result = `/usr/bin/du -b #{x}`
      #  print result;
        fastq_array = result.split("\t")
        match = fastq_array[1] =~ $FASTQ_PATTERN

        if(flag=="rerun")
          data_type = $4.to_s
          lane = $2.to_i
          replicates = $3.to_i
        else
          data_type = $2.to_s
          lane = $4.to_i
          replicates = $5.to_i
        end



        if (data_type == "Undetermined")
          newname = File.join(flowcell.unaligned_dir,"n_#{lane}_#{replicates}_Undetermined.fastq.gz")
          lane = "Undetermined_#{lane}"

        else
          if(flag=="dual")
            library,barcode1,barcode2 = data_type.split(/-/)
            newname = File.join(flowcell.unaligned_dir,"n_#{lane}_#{replicates}_#{barcode1}-#{barcode2}.fastq.gz")

            barcode_hash["#{replicates}_#{barcode1}-#{barcode2}"] = library

          else
            library,barcode,index = data_type.split(/-/)

            if !index
              newname = File.join(flowcell.unaligned_dir,"n_#{lane}_#{replicates}_#{barcode}.fastq.gz")
              barcode_hash["#{replicates}_#{barcode}"] = lane
            else
              newname = File.join(flowcell.unaligned_dir,"n_#{lane}_#{replicates}_#{index}.fastq.gz")
              barcode_hash["#{replicates}_#{index}"] = lane
            end

          end

          lane = "Regular_#{lane}"

        end

        size = fastq_array[0].to_i

        if(fastq_hash.has_key?(lane))
          temp = fastq_hash[lane].to_i
          fastq_hash[lane] = temp+size
        else
          fastq_hash[lane] = size
        end


        if(flag!="rerun")
          #rename fastq files
          command =  "mv #{x} #{newname}"
          puts command
          system command

        end
      end


      # for nextseq cat all fastq files by lane
      system "mkdir -p #{flowcell.fastq_combine_dir}"
      puts barcode_hash

      barcode_hash.keys.each do |x|
        if x != nil
          # puts barcode_hash.values
          cat_command = "cat #{flowcell.unaligned_dir}/n_*_#{x}.fastq.gz > #{flowcell.fastq_combine_dir}/n_#{x}.fastq.gz"
          puts cat_command
          system cat_command


        end
      end


    elsif type=="hiseq"
      fastq_files_regular = Dir.glob(File.join(flowcell.fastq_combine_dir, "*.fastq.gz"))
      fastq_files_undertermined = Dir.glob(File.join(flowcell.unaligned_undetermined_combine_dir, "*.fastq.gz"))
      $FASTQ_PATTERN = /s_(\d)_(\d)_(.*)/

      system "cd #{flowcell.fastq_combine_dir}"

      fastq_files_regular.each do |x|

        result = `/usr/bin/du -b #{x}`
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

        result = `/usr/bin/du -b #{x}`
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
    else
      puts "Please specify type: nextseq or hiseq"
    end


    fastq_summary = File.join(flowcell.base_dir,"fastq_stat_#{flowcell_id}.txt")
    fastq_barplot = File.join(flowcell.base_dir,"fastq_stat_#{flowcell_id}.jpeg")

    File.open(fastq_summary, 'w') do |file|
      fastq_hash.each do |x,y|
        group = x.split("_")
        file.puts "#{group[0]}:#{group[1]}:#{y}"
      end
    end

   system "/n/local/bin/Rscript /n/ngs/tools/pilluminati/bin/barplot.r #{fastq_summary} #{fastq_barplot}"
   Illuminati::Emailer.email "fastq files stats: #{flowcell_id}" , fastq_barplot, fastq_summary

  else
    puts "ERROR: No flowcell_id"
  end
end


