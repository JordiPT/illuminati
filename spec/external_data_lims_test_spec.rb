require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'illuminati/external_data_lims_test'


describe Illuminati::ExternalDataLimsTest do
  before(:each) do
    @lims = Illuminati::ExternalDataLimsTest.new
  end

  it "should handle different flowcell ids" do

  end
  describe "simulate YML data functionality" do
    before(:each) do
      @lims = Illuminati::ExternalDataLimsTest.new
    end

    it "should generate sample data" do
      good_samples = [{:lane=>"1", :name=>"9.5dpc_HoxB1_input", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"2", :name=>"HoxB1_3FMS_myc_M2Flag_IP", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"3", :name=>"HoxB1_3FMS_myc_myc_IP", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"4", :name=>"HoxB1_3FMS_myc_input", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"5", :name=>"HoxB1_HF_M2Flag_IP", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"6", :name=>"HoxB1_HF_M2Flag_input", :genome=>"mm9", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}, {:lane=>"7", :name=>"Pbx_input", :genome=>"mm9", :protocol=>"eland_extended", :bases=>"Y*", :barcode_type=>:none, :barcode=>""}, {:lane=>"8", :genome=>"phiX", :name=>"Phi X", :protocol=>"eland_extended", :barcode_type=>:none, :barcode=>""}]
      @lims.sample_data_for("639KBAAXX").should == good_samples
    end

    it "should generate distribution data" do
      good_distributions = [{:lane=>1, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>2, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>3, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>4, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>5, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>6, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}, {:lane=>7, :path=>"/n/analysis/Krumlauf/bdk/Krumlauf-2011-06-23/639KBAAXX"}]

      @lims.distributions_for("639KBAAXX").should == good_distributions
    end
  end
end
