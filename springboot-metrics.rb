#! /usr/bin/env ruby
#
#   uchiwa-health
#
# DESCRIPTION:
#   get metrics of of Spring Boot 1.2.x application using actuator endpoints

#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: uri
#
# USAGE:
#  #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Victor Pechorin <dev@pechorina.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'net/https'
require 'json'
require 'uri'

class SpringBootMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Your spring boot actuator endpoint',
         required: true,
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Your app port',
         required: true,
         default: 8080

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'Your app username',
         required: false

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'Your app password',
         required: false

  option :path,
         short: '-e PATH',
         long: '--path PATH',
         description: 'Metrics endpoint path',
         required: true,
         default: '/metrics'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: "#{Socket.gethostname}.springboot_metrics"

  option :counters,
         description: 'Include counters',
         short: '-c',
         long: '--counters',
         boolean: true,
         default: false

  option :gauges,
         description: 'Include gauges',
         short: '-g',
         long: '--gauges',
         boolean: true,
         default: false

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def run
    endpoint = "http://#{config[:host]}:#{config[:port]}"
    url      = URI.parse(endpoint)

    begin
      res = Net::HTTP.start(url.host, url.port) do |http|
        req = Net::HTTP::Get.new(config[:path])
        if (config[:username] && config[:password])
          req.basic_auth(config[:username], config[:password])
        end
        http.request(req)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse,
           Net::HTTPHeaderSyntaxError, Net::ProtocolError, Errno::ECONNREFUSED => e
      critical e
    end

    if json_valid?(res.body)
      json = JSON.parse(res.body)
      json.each do |key, val|
        if key.to_s.match(/^counter\.(.+)/)
          if (config[:counters])
            output(config[:scheme] + '.' + key, val)
          end
        elsif key.to_s.match(/^gauge\.(.+)/)
          if (config[:gauges])
            output(config[:scheme] + '.' + key, val)
          end
        else
          output(config[:scheme] + '.' + key, val)
        end
      end
    else
      critical 'Response contains invalid JSON'
    end

    ok
  end
end
