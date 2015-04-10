#! /usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'illuminati'

TEST = false

flowcell_id = ARGV[0]
type = ARGV[1]


if flowcell_id
  paths = Illuminati::FlowcellPaths.new flowcell_id, TEST
  flowcell = Illuminati::FlowcellRecord.find flowcell_id, paths
  notifier = Illuminati::LimsNotifier.new(flowcell)
  notifier.upload_to_lims(type)
  #notifier.complete_analysis
else
  puts "no flowcell"
end
