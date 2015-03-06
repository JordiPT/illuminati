#! /usr/bin/env ruby

#
# Script to allow access to emailer class and functionality
# to scripts external to Illuminati.
# Used in the run script to email at the start of the
# primary analysis pipeline
#
$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'illuminati'

if __FILE__ == $0
  title = ARGV[0]
  file1 = ARGV[1]
  file2 = ARGV[2]
  if title
    Illuminati::Emailer.email title, file1, file2
  else
    puts "ERROR: call with title of email"
  end
end
