#! /usr/bin/env ruby
#
#   check-opentsdb-query
#
# DESCRIPTION:
#   Check OpenTSDB queries
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: jsonpath
#   gem: json
#   gem: dentaku
#
# USAGE:
#   example commands
#
#
# LICENSE:
#   Copyright 2014, Fraser Scott <fraser.scott@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'json'
require 'net/http'
require 'net/https'
require 'dentaku'

# VERSION = '0.1.0'

#
#
class CheckOpenTSDBQuery < Sensu::Plugin::Check::CLI
  check_name nil
  option :host,
         short: '-H HOST',
         long: '--host HOST',
         default: 'localhost',
         description: 'OpenTSDB host'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         default: '4242',
         description: 'OpenTSDB port'

  option :use_ssl,
         description: 'Turn on/off SSL (default: false)',
         short: '-s',
         long: '--use_ssl',
         boolean: true,
         default: false

  option :query,
         short: '-q QUERY',
         long: '--query QUERY',
         required: true,
         description: 'Query to run. See http://opentsdb.net/docs/build/html/api_http/query/index.html'

  option :start,
         short: "-t START",
         long: "--state START",
         default: "5m-ago",
         description: 'Start time of query'

  option :alias,
         short: '-a ALIAS',
         long: '--alias ALIAS',
         default: nil,
         description: 'Alias of query (e.g. if query and output gets too long)'

  option :noresult,
         short: '-n',
         long: '--noresult',
         boolean: true,
         description: 'Go critical for no result from query'

  option :warning,
         short: '-w WARNING',
         long: '--warning WARNING',
         default: nil,
         description: "Warning threshold expression. E.g. 'value >= 10'. See https://github.com/rubysolo/dentaku"

  option :critical,
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         default: nil,
         description: "Critical threshold expression. E.g. 'value >= 20'. See https://github.com/rubysolo/dentaku"

  option :help,
         short: '-h',
         long: '--help',
         description: 'Show this message',
         on: :tail,
         boolean: true,
         show_options: true,
         exit: 0

  # option :version,
  #        short: '-v',
  #        long: '--version',
  #        description: 'Show version',
  #        on: :tail,
  #        boolean: true,
  #        proc: proc { puts "Version #{VERSION}" },
  #        exit: 0

  def opentsdb_url
    schema = "http"
    if config[:use_ssl]
      schema = "https"
    end

    url = "#{schema}://#{config[:host]}:#{config[:port]}/api/query?m=#{config[:query]}&start=#{config[:start]}"
    URI.parse(url)
  end
  
  def run
    url = opentsdb_url()

    req = Net::HTTP::Get.new(url)
    nethttp = Net::HTTP.new(url.host, url.port)
    if config[:use_ssl]
      nethttp.use_ssl = true
    end
    resp = nethttp.start { |http| http.request(req) }

    unless resp.kind_of? Net::HTTPSuccess
      unknown "Bad response from OpenTSDB server"
    end

    metric = JSON.parse(resp.body)
    if metric.is_a?(Array)
      metric = metric.first
    end
    value =metric["dps"].values[0]
    
    if config[:noresult] && value.empty?
      critical "No result for query '#{query}'"
    end

    calc = Dentaku::Calculator.new
    if config[:critical] && calc.evaluate(config[:critical], value: value)
      critical "Value '#{value}' matched '#{config[:critical]}' for query '#{config[:query]}'"
    elsif config[:warning] && calc.evaluate(config[:warning], value: value)
      warning "Value '#{value}' matched '#{config[:warning]}' for query '#{config[:query]}'"
    else
      ok "Value '#{value}' ok for query '#{config[:query]}'"
    end
  end
end
