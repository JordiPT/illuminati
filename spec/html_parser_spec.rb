require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'illuminati/html_parser'

class FakePathsReport
  attr_accessor :base_dir, :unaligned_dir, :id

  def initialize
    @base_dir = File.expand_path(File.dirname(__FILE__) + "/data")
    @out_dir = File.expand_path(File.dirname(__FILE__) + "/sandbox")
    @unaligned_dir = File.join(@base_dir, 'Unaligned')
    @id = "639KBAAXX"
  end

  def unaligned_stats_dir
    @base_dir
  end

  def aligned_stats_dirs
    [File.join(@base_dir, "Aligned_Summary_Stats")]
  end

  def aligned_stats_dir
    aligned_stats_dirs[0]
  end

  def to_h
    {}
  end
end

describe Illuminati::HtmlParser do
  before(:each) do
    @paths = FakePathsReport.new
    @parser = Illuminati::HtmlParser.new
  end

  it "should parse html into tree" do
    simple_html = "<body>\n<p>Terrible HTML</p><table><tr><td>Project Name</td><td>Project dada</td></tr></table></body>"
    example_results = {:tag=>"body", :content=>"", :children=>[{:tag=>"p", :content=>"Terrible HTML"}, {:tag=>"table", :content=>"", :children=>[{:tag=>"tr", :content=>"", :children=>[{:tag=>"td", :content=>"Project Name"}, {:tag => "td", :content =>"Project dada"}]}]}]}
    doc = @parser.parse_html(simple_html)
    doc.to_h.should == example_results
    tables = doc.find('table')
    tables.size.should == 1
    tds = doc.find('td')
    tds.size.should == 2
    tables[0].contains?('td').should == true
  end

  describe "Sample Summary" do
    before(:each) do
      @sample_summary_filename = File.join(@paths.aligned_stats_dir, "#{@paths.id}_Sample_Summary.htm")
      File.exists?(@sample_summary_filename).should == true
    end

    it "should parse sample summary file to html doc" do
      doc = @parser.parse_file(@sample_summary_filename)
      tables = doc.find('table')
      tables.size.should == 14
      headers = tables.collect {|t| t.contains?('th')}
    end

    it "should parse tables" do
      table_data = @parser.table_data(@sample_summary_filename)
      table_data.size.should == 6
      table_data[1].size.should == 8
      table_data[1][0]["Sample"].should == "1"
      table_data[1][-1]["Sample"].should == "8"
    end
  end

  describe "Demultiplexed Stats" do
    before(:each) do
      @paths.id = "639P5AAXX"
      @demultiplex_stats_filename = File.join(@paths.unaligned_stats_dir,"#{@paths.id}_Demultiplex_Stats.htm")
      File.exists?(@demultiplex_stats_filename).should == true
    end

    it "should parse demultiplex stats file html to doc" do
      doc = @parser.parse_file(@demultiplex_stats_filename)
      tables = doc.find('table')
      tables.size.should == 4
    end

    it "should parse tables" do
      doc = @parser.parse_file(@demultiplex_stats_filename)
      table_data = @parser.parse_tables(doc)
      table_data.size.should == 2
    end
  end
end

