#!/usr/bin/env ruby

# fetch data from lims
require 'optparse'
require 'net/http'
require 'uri'
require 'json'

API_TOKEN = '1c5b55787c806548'

NGS_LIMS = "http://limskc01/zanmodules/molbio/api/ngs/"

getFlowcell = NGS_LIMS + 'flowcells/getFlowcell'
getSamples  = NGS_LIMS + 'flowcells/getSamples'

def get_connection(uri, api_token)
  url = URI.parse(uri)
  req = Net::HTTP::Post.new(url.path, initheader = {'Content-Type' => 'application/json'})
  req.basic_auth 'apitoken', api_token
  return url, req
end

def json_data_for url, auth_req, fc_id
    params = { "fcIdent" => fc_id}
    auth_req.body = params.to_json
    resp = Net::HTTP.new(url.host, url.port).start {|http| http.request(auth_req) }
    resp.body
end

def query_connection url, connection, flowcell_ids
  fc_id_n = flowcell_ids.split(',').map(&:strip)
  output_array = []
  fc_id_n.each do |req_fc_id|
    lims_results = json_data_for(url, connection, req_fc_id)
    # handle inconsistency in lims api
    if lims_results != 'false'
      json_lims    = JSON.parse(lims_results)
      unless json_lims["message"] =~ /Invalid/
        output_array.push(json_lims)
      end
    end
  end
  return JSON.dump(output_array)
end

def print data
  data.each do |sample|
    output_array = []
    output_array << sample
    puts output_array.join("\t")
  end
end

def run_query query_url, args
  # optional comma-delimited orders
  url_path = query_url
  url, connection = get_connection(url_path, API_TOKEN)
  puts query_connection url, connection, args
end

HELP = <<-HELP
Usage: lims_fc_info [COMMAND] <OPTIONS>

lims_fc_info Commands:
  version - Print version number and exit
  help    - Print this help and exit
  
  * Multiple requests can be packaged by seperating args with a comma (,)
  * i.e. FC1,FC2
  
  samples  - Return JSON data from LIMS for sample data from flowcells
  flowcell - Return JSON data from LIMS for flowcells meta-data

HELP

command = ARGV.shift

case command
when "samples"
  # run samples query
  run_query getSamples, ARGV[0]
when "flowcell"
  # run flowcell query
  run_query getFlowcell, ARGV[0]
else
  puts HELP
end
