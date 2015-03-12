#!/usr/bin/env ruby



LIMS_SCRIPT_PATH = "/n/ngs/tools/lims/lims_data.pl"
MAIL_SCRIPT_PATH = "/n/ngs/tools/pilluminati/bin/emailer.rb"
BOWTIE2_INDEXES = "/n/ngs/igenome/bowtie2/"
GENOMES_ROOT = "/n/ngs/igenome/"

require 'json'


flowcell_id = ARGV[0]

def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def cyan(text); colorize(text, 36); end

def json_data_for flowcell_id
  script = "perl #{LIMS_SCRIPT_PATH}"
  lims_results = %x[#{script} #{flowcell_id}]
  lims_results.force_encoding("iso-8859-1")
  data = {"samples" => []}
  unless lims_results =~ /^[F|f]lowcell not found/
    data = JSON.parse(lims_results)
  end
  data
end

def check_barcodes flowcell_data

  rtn = true
  single = false
  custom = false
  dual_lanes = []
  custom_lanes = []

  if flowcell_data['samples'].size < 1
    puts red('flowcell not found')
    rtn = false
  else
    flowcell_data['samples'].each do |sample|
      if sample['indexSequences']
        if sample['indexSequences'] == [""]
          puts cyan("indexSequences is blank, lane #{sample['laneID']}. Verify that this was intentional in lims and it should be okay.")
        end
        if sample['indexSequences'].size > 1
          rtn = false
          dual_lanes << sample['laneID']
        else
          single = true
        end
        
      else
         puts cyan("no indexes, lane #{sample['laneID']}. Verify that this was intentional in lims and it should be okay.")
      end

      if sample['indexType'] == "Single Custom"
        custom = true
        custom_lanes << sample['laneID']
      end
      if ['ILL', 'Illumina TruSeq', 'Illumina','Nugen','NEB','Rubicon R40048','Rubicon_Dual','BIOO','BiooScientific','BioScientific','BiooSci_Fake','BiooSci_Trimmed'].include? sample['indexType']
      else
        puts red("indexType is #{sample['indexType']}, lane #{sample['laneID']}")
      end
    end

    if custom
      puts red("indexType is single custom, lane #{custom_lanes.uniq.join(",")}. Pipeline doesn\'t really deal with this yet. Create custom SampleSheet.csv to run pipeline or add Indexes to lims and update external_data_lims.rb with the new type.")
    else
      if !rtn and single
        puts red("mix of dual and single indexes found, dual in lane #{dual_lanes.uniq.join(",")}. Might be dual indexed libraries run as single or vice versa. Modify SampleSheet.csv and configureBclToFastq --use-bases-mask.")
      else
        if !rtn and !single
          puts red("dual indexes found. Run startup_run.rb #{flowcell_data['FCID']} --dual")
        else
          puts green("all single indexes. startup_run.rb #{flowcell_data['FCID']}")
        end
      end
    end
  end
  rtn
end



def check_genomes flowcell_data
  species = ""
  rtn = true
  missing_lanes = []
  genomes = []
  bowtie_index = []
  ref_genome = []

  flowcell_data['samples'].each do |sample|
    if sample.include?('genomeVersion')
      genomes << sample['genomeVersion']
      bowtie_index << File.exists?(File.join(BOWTIE2_INDEXES, "#{sample['genomeVersion']}.1.bt2"))
      ref_genome << directory_exists?(File.join(GENOMES_ROOT, "#{sample['genomeVersion']}/"))
      
      if sample['genomeVersion'].strip.size == 0 or sample['genomeVersion'].strip.downcase == 'none'
        rtn = false
        missing_lanes << sample['laneID']
        species = sample['speciesName']
      else
        if sample['speciesName'][0].downcase != sample['genomeVersion'][0].downcase
          puts cyan("species name and genome check: #{sample['speciesName']} #{sample['genomeVersion']}")
        #check reference genome and bowtie index existence
        end
      end
    else
      if sample['isControl'] == 1
        puts cyan("control has no genome. Should be okay.")
      else
        rtn = false
        missing_lanes << sample['laneID']
      end
    end
  end
  
  
  if !rtn
    puts green("genomes: #{genomes.uniq.join(",")}.")
    puts cyan("missing genome: #{missing_lanes.uniq.join(",")}. Species is #{species}. To run without alignment, do startup_run.rb #{flowcell_data['FCID']} --no-align")
  else
    puts green("genomes: #{genomes.uniq.join(",")}.")
  end
  
  if bowtie_index.uniq.join(",")!="true"
    puts red("Missing Bowtie Index File, Run bowtie-build under /n/ngs/igemone/bowtie2/")
  else
    puts green("Bowtie Index File Found!")
  end
  
  if ref_genome.uniq.join(",")!="true"
    puts red("Missing Reference Genome File, Add genome under /n/ngs/igemone/")
 else
    puts green("Reference Genome File Found!")
  end
  
  rtn
end

def directory_exists?(directory)
  File.directory?(directory)
end

def check_machine flowcell_data
  rtn = true
  nextseq = false
  hiseq = false
  missing_lanes = []
  flowcell_data['samples'].each do |sample|
    if sample['readLength'] =~ /^N/
      nextseq = true
    end
    if sample['readLength'] =~ /^H/
      hiseq = true
    end
  end
  if nextseq 
    if hiseq
      puts red("Samples are labeled both Nextseq and Hiseq. Check lims.")
    else
      puts red("Nextseq run. startup_run.rb #{flowcell_data['FCID']} --nextseq")
    end
  end
  rtn
end

def check_paired flowcell_data
  missing_lanes = []
  rtn = true
  if flowcell_data['samples'][0]
    previous = flowcell_data['samples'][0]['readType']
    flowcell_data['samples'].each do |sample|
      if (sample['readType'] == 'Single Read' or sample['readType'] == 'Paired Reads') and sample['readType']==previous
        previous=sample['readType']
      else
        rtn = false
        missing_lanes << sample['laneID']
      end
    end
    if !rtn
      puts red("mixed Single Read / Paired Reads on the same flowcell, check lims and change use-bases-mask if needed? lane #{missing_lanes.uniq.join(",")}.")
    end
  else
  end
  rtn
end

def check_lims flowcell_id
  rtn = true
  flowcell_data = json_data_for(flowcell_id)
  genomes = check_genomes(flowcell_data)
  barcodes = check_barcodes(flowcell_data)
  machine = check_machine(flowcell_data)
  paired = check_paired(flowcell_data)
  if barcodes
  else
    rtn = false
  end
  #puts flowcell_data
  #puts genomes
  rtn
end

valid = check_lims(flowcell_id)

# valid = false

