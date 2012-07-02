class Hash
  #take keys of hash and transform those to a symbols
  def self.transform_keys_to_symbols(value)
    return value if not value.is_a?(Hash)
    hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
    return hash
  end
end


module Illuminati
  class ExternalDataYml

    attr_accessor :filename

    def initialize filename
      super
      self.filename = filename
    end

    def load_data
      if File.exists? self.filename
        @data = Hash[YAML::load(open(self.filename))]
        @data = Hash.transform_keys_to_symbols(@data)
      else
        raise "ExternalDataYml: no file found #{filename}"
      end
    end

    #
    # This method returns an array of hashes describing each sample in the flowcell
    # with the ID of flowcell_id.
    # Each hash contains the following keys:
    # {
    #   :lane => String name of lane (1 - 8),
    #   :name => Sample name.
    #   :genome => Code for genome used for lane. Should correlate to folder name in genomes dir,
    #   :protocol => Should be either "eland_extended" or "eland_pair",
    #   :barcode_type => Should be :illumina, :custom, or :none
    #   :barcode => If :barcode_type is not :none, this provides the 6 sequence barcode
    #   :raw_barcode => Sequence to feed back to LIMS for reported barcode. No restriction on content.
    # }
    #
    def sample_data_for flowcell_id
      @data || load_data
      @data[:samples] ? @data[:samples] : []
    end

    def distributions_for flowcell_id
      @data || load_data
      @data[:samples] ? @data[:samples] : []
      @data[:distributions] ? @data[:distributions] : []
    end
  end
end
