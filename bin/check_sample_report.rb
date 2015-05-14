#! /usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'illuminati'

if __FILE__ == $0
  flowcell_id = ARGV[0]

  if flowcell_id
    flowcell = Illuminati::FlowcellPaths.new flowcell_id

    sample_report = File.join(flowcell.base_dir,ARGV[1])
    system "cd #{flowcell.base_dir}"
    fastq_hash = Hash.new
    $FASTQ_PATTERN=/(.*)_(\d)_(\d)_([ATCGN-]+).fastq.gz/
    flag=true

    File.open(sample_report).each do |line|

    if  line.start_with?"output"
    else
      if line.include?"\r"
        puts "ERROR: dos line endings Found!"
        line.gsub(/\r\n/,"\n")
        flag=false
        File.open("Sample_Report.csv.new","w"){|file| file.write(line)}
      end

      data_array = line.split(",")

      match = data_array[0] =~ $FASTQ_PATTERN

      index = $4.to_s

      if index!=data_array[6]
        puts "#{index}:#{data_array[6]}"
        puts "ERROR: Index doesn't match between fastq names"
        flag=false
      end

      if(fastq_hash.has_key?(data_array[0]))
        puts "ERROR: duplicated fastq name!"
        flag=false
      else
        fastq_hash[data_array[0]]=data_array[6]
      end

      end
    end
    if flag==true
      puts "Correct Sample Report. Everything seems fine!"
    end
  end
end