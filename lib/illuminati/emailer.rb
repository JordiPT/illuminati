require 'illuminati/constants'

module Illuminati
  #
  # Helper class to facilitate the emailing of messgages and files.
  #
  class Emailer
    #
    # Email a message and optional file content. Email addresses that will
    # be sent to when this method is called are defined in the EMAIL_LIST
    # array in constants.rb
    #
    # == Parameters:
    # title::
    #   string that will be used as the title of the email
    #
    # file::
    #   optional filename. If not nil, the contents of the file will
    #   be echoed into the body of the email.
    def self.email title,  file1 = nil, file2 = nil
      EMAIL_LIST.each do |address|

        if file1
          command = "mutt -a \"#{file1}\" -s \"#{title}\" -- #{address} < \"#{file2}\""

        else
          command = "mail -s \"#{title}\" #{address}"
          command = "echo \"that is all\" | #{command}"
        end
        puts command
        results = %x[#{command}]
        puts results
      end
    end
  end
end

