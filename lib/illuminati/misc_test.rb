require 'json'

flowcell_data = ['H0T64AGXX']

## old method
#flowcell_data.each do |flowcell_id|
#  script = "~/dev/illuminati/scripts/lims_data.pl"
#  lims_results = %x[#{script} #{flowcell_id}]
#  lims_results.force_encoding("iso-8859-1")
#  data = {"samples" => []}
#  unless lims_results =~ /^[F|f]lowcell not found/
#    data = JSON.parse(lims_results)
#  end 
#  sample_datas = []
#  data["samples"].each do |lims_sample_data|
#    sample_datas.push(lims_sample_data)
#  end
#  puts sample_datas
#  #if not sample_datas.empty?
#  #  puts "#{order_id}    #{flowcell_id}    #{sample_datas.length}"
#  #end
# 
#end

def next_seq_only data_array
  # data_array: an array of JSON records containg flowcell attributes
  nextseq = []
  for d in data_array do
    if d['illuminaRtaPipelineVer'] =~ /NextSeq/ || d['clusterKit'] =~ /NextSeq/ || d['seqKit'] =~ /NextSeq/
      nextseq << d
    end
  end
  nextseq
end

#flowcell_data.each do |flowcell_id|
#  script = "~/dev/illuminati/scripts/lims_fc_info.rb"
#  lims_results = %x[#{script} "flowcell" #{flowcell_id}]
#  lims_results.force_encoding("iso-8859-1")
#  puts lims_results
#  data = JSON.parse(lims_results)
#  puts data
#  next_seq = next_seq_only data
#  puts next_seq.length
#  #puts data
#end

def data_for2 flowcell_id, query="samples"
  script = "~/dev/illuminati/scripts/lims_fc_info.rb"
  lims_results = %x[#{script} #{query} #{flowcell_id}]
  lims_results.force_encoding("iso-8859-1")
  data = JSON.parse(lims_results)
  if data.empty? and query == "samples"
    data = {"samples" => []}
  else
    if query == "samples"
      d_samples = {}
      d_samples["samples"] = data.collect{|d| d["samples"] }.flatten
      data = d_samples
    else
      data = data.each{|d| d.update({"status"=> nil}) }
    end
  end
  data
end


flowcell_data.each do |flowcell_id|
  #puts data_for2 flowcell_id, "flowcell"
  #puts data_for2 flowcell_id
  
  #data = data_for2 flowcell_id
  
  options = {:sample_sheet_file=>"SampleSheet.csv", :runfolder_dir=>"/Users/srm/tmp/"}
  
  # create external data lims
  fc_lims_data = Illuminati::ExternalDataLims.new 
  fc_sample_data = fc_lims_data.sample_data_for flowcell_id
  
  nxss = NextSeqSampleSheet.new options, fc_sample_data

  #script = "~/dev/illuminati/scripts/lims_fc_info.rb"
  #lims_results = %x[#{script} "flowcell" #{flowcell_id}]
  #lims_results.force_encoding("iso-8859-1")
  #puts q(lims_results, "flowcell")
  #lims_results = %x[#{script} "samples" #{flowcell_id}]
  #lims_results.force_encoding("iso-8859-1")
  #puts q(lims_results)
end
