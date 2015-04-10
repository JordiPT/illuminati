require 'illuminati/config'

module Illuminati
  config = Config.parse_config

  # Location of CASAVA 1.8's bin directory
  CASAVA_PATH         = File.expand_path config['casava_path']
  # Location of bclTofastq bin directory
  BCL2FASTQ_PATH         = File.expand_path config['bcl2fastq_path']
  # List emailer uses to email out messages.
  EMAIL_LIST          = config['email_list']
  # Path to put quality control files in.
  QC_PATH             = File.expand_path config['qc_path']

  # Location where startup scripts will be placed.
  ADMIN_PATH          = File.expand_path config['admin_path']
  # Location of log files.
  LOGS_PATH           = File.expand_path config['logs_path']
  # Root directory of location of flowcell run directories.
  FLOWCELL_PATH_BASE  = File.expand_path config['flowcell_path_base']
  # Root directory of location of outsource flowcell run directories.
  OUTSOURCE_PATH_BASE  = File.expand_path config['outsource_path_base']

  ASSESTS_PATH = File.join(File.dirname(__FILE__), "..", "..", "assests")
  NUM_PROCESSES = config['num_processes']


  # Relative path of the Basecalls directory
  BASECALLS_PATH      = config['basecalls_path']
  # Relative path of Illuminati's fastq renaming directory.
  FASTQ_COMBINE_PATH  = config['fastq_combine_path']
  # Relative path of Illuminati's fastq renaming directory.
  FASTQ_UNDETERMINED_COMBINE_PATH = config['fastq_undetermined_combine_path']
  # Relative path of Illuminati's export renaming directory.
  ELAND_COMBINE_PATH  = config['eland_combine_path']
  # Relative path of Illuminati's fastq filtering directory.
  FASTQ_FILTER_PATH   = config['fastq_filter_path']
  # Pattern to use when searching for the Project directory.
  PROJECT_PATTERN     = config['project_pattern']
  # Pattern to use when searching for the unaligned stats directory.
  FASTQ_STATS_PATTERN = config['fastq_stats_pattern']
  # Pattern to use when searching for the aligned stats directory.
  ELAND_STATS_PATTERN = config['eland_stats_pattern']

  # where the genomes are stored.
  GENOMES_ROOT = config['genomes_root']

  EMAIL_SERVER = config['email_server']
  EMAIL_RECIPIENTS = config['email_list'].join(',')
  WEB_DIR_ROOT = config['web_dir_root']
  NUM_LEADING_DIRS_TO_STRIP  = config['num_leading_dirs_to_strip']
  
  BCL2FASTQ2_PATH   = File.expand_path config['bcl2fastq2']
  BCL2FASTQ2_PROC   = 8
  NEXTSEQ_UNALIGNED = config['nextseq_unaligned']
  NEXTSEQ_ALIGNED   = config['nextseq_aligned']
  
  BOWTIE2           = config['bowtie2']
  BOWTIE2_PROC      = config['bowtie2_proc']
  BOWTIE2_SGE_PROC  = config['bowtie2_sge_proc']
  BOWTIE2_INDEXES   = config['bowtie2_indexes']
  
end

module Illuminati
  class ScriptPaths
    def self.internal_scripts_path
      File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "scripts"))
    end
    
    def self.fastqc_script
      File.join(internal_scripts_path, "fastqc.pl")
    end

    def self.lims_info
      File.join(internal_scripts_path, "lims_info")
    end

    def self.lims_data
      File.join(internal_scripts_path, "lims_data.pl")
    end

    def self.lims_upload_script
      File.join(internal_scripts_path, "lims_upload_samples.rb")
    end

    def self.lims_complete_script
      File.join(internal_scripts_path, "lims_flowcell_complete.pl")
    end
    
    def self.lims_fc_info
      File.join(internal_scripts_path, "lims_fc_info.rb")
    end
    
    def self.bcl2fastq2_script
      File.join(ASSESTS_PATH, "bcl2fastq2.sh")
    end

    def self.bcl2fastq2_script_dual
      File.join(ASSESTS_PATH, "bcl2fastq2_dual.sh")
    end
    
    def self.bowtie2_script
      File.join(ASSESTS_PATH, "bowtie2.sh")
    end
    
    def self.bowtie2_array
      File.join(ASSESTS_PATH, "bowtie2_array.sh")
    end
    
  end
end

module Illuminati
  class Paths
    @@base = nil
    def self.base
      @@base || FLOWCELL_PATH_BASE
    end

    def self.set_base new_base
      @@base = new_base
    end
  end
end
