# TODO: make poll_wait tunable
# TODO: add options to sort ascending or descending on date
# TODO: implement searching logs (is this really useful?)
# TODO: add duplicate line detection and compression (...)

require 'collins-cli'
require 'set'
require 'cgi'

module Collins::CLI
  class Log

    include Mixins

    LOG_LEVELS = Collins::Api::Logging::Severity.constants.map(&:to_s)
    OPTIONS_DEFAULTS = {
      :tags => [],
      :show_all => false,
      :poll_wait => 2,
      :follow => false,
      :severities => [],
      :timeout => 20,
      :sev_colors => {
        'EMERGENCY'     => {:color => :red, :background => :light_blue},
        'ALERT'         => {:color => :red},
        'CRITICAL'      => {:color => :black, :background => :red},
        'ERROR'         => {:color => :red},
        'WARNING'       => {:color => :yellow},
        'NOTICE'        => {},
        'INFORMATIONAL' => {:color => :green},
        'DEBUG'         => {:color => :blue},
        'NOTE'          => {:color => :light_cyan},
      },
      :config => nil
    }
    SEARCH_DEFAULTS = {
      :size => 20,
      :filter => nil,
    }
    PROG_NAME = 'collins log'

    def initialize
      @parsed = false
      @validated = false
      @running = false
      @collins = nil
      @logs_seen = []
      @options = OPTIONS_DEFAULTS.clone
      @search_opts = SEARCH_DEFAULTS.clone
    end

    def parse!(argv = ARGV)
      raise "No flags given! See --help for #{PROG_NAME} usage" if argv.empty?
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        opts.on('-a','--all',"Show logs from ALL assets") {|v| @options[:show_all] = true}
        opts.on('-n','--number LINES',Integer,"Show the last LINES log entries. (Default: #{@search_opts[:size]})") {|v| @search_opts[:size] = v}
        opts.on('-t','--tags TAGS',Array,"Tags to work on, comma separated") {|v| @options[:tags] = v}
        opts.on('-f','--follow',"Poll for logs every #{@options[:poll_wait]} seconds") {|v| @options[:follow] = true}
        opts.on('-s','--severity SEVERITY[,...]',Array,"Log severities to return (Defaults to all). Use !SEVERITY to exclude one.") {|v| @options[:severities] = v.map(&:upcase) }
        #opts.on('-i','--interleave',"Interleave all log entries (Default: groups by asset)") {|v| options[:interleave] = true}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| @options[:config] = v}
        opts.on('-h','--help',"Help") {puts opts ; exit 0}
        opts.separator ""
        opts.separator <<_EOE_
Severities:
  #{Collins::Api::Logging::Severity.to_a.map{|s| s.colorize(@options[:sev_colors][s])}.join(", ")}

Examples:
  Show last 20 logs for an asset
    #{PROG_NAME} -t 001234
  Show last 100 logs for an asset
    #{PROG_NAME} -t 001234 -n100
  Show last 10 logs for 2 assets that are ERROR severity
    #{PROG_NAME} -t 001234,001235 -n10 -sERROR
  Show last 10 logs all assets that are not note or informational severity
    #{PROG_NAME} -a -n10 -s'!informational,!note'
  Show last 10 logs for all web nodes that are provisioned having verification in the message
    collins find -S provisioned -n webnode\$ | #{PROG_NAME} -n10 -s debug | grep -i verification
  Tail logs for all assets that are provisioning
    collins find -Sprovisioning,provisioned | #{PROG_NAME} -f
_EOE_
      end.parse!(argv)
      @parsed = true
      self
    end

    def validate!
      raise "Options not yet parsed with #parse!" unless @parsed
      unless @options[:severities].all? {|l| Collins::Api::Logging::Severity.valid?(l.tr('!','')) }
        raise "Log severities #{@options[:severities].join(',')} are invalid! Use one of #{LOG_LEVELS.join(', ')}"
      end
      @search_opts[:filter] = @options[:severities].join(';')
      if @options[:tags].empty? and not @options[:show_all]
        # read tags from stdin. first field on the line is the tag
        begin
          input = ARGF.readlines
        rescue Interrupt
          raise "Interrupt reading tags from ARGF"
        end
        @options[:tags] = input.map{|l| l.split(/\s+/)[0] rescue nil}.compact.uniq
      end
      raise "You need to give me some assets to display logs; see --help" if @options[:tags].empty? and not @options[:show_all]
      @validated = true
      self
    end

    def run!
      raise "Options not yet validated with #validate!" unless @validated
      raise "Already running" if @running

      begin
        @running = true
        # collins sends us messages that are HTML escaped
        all_logs = grab_logs
        all_logs.map! {|l| l.MESSAGE = CGI.unescapeHTML(l.MESSAGE) ; l }
        @logs_seen = all_logs.map(&:ID).to_set
        output_logs(all_logs)
        while @options[:follow]
          sleep @options[:poll_wait]
          logs = grab_logs
          new_logs = logs.reject {|l| @logs_seen.include?(l.ID)}
          output_logs(new_logs)
          @logs_seen = @logs_seen | new_logs.map(&:ID)
        end
        return true
      rescue Interrupt
        return true
      rescue
        return false
      ensure
        @running = false
      end
    end

    private

    def output_logs(logs)
      # colorize output before computing width of fields
      logs.map! do |l|
        l.TYPE = @options[:sev_colors].has_key?(l.TYPE) ? l.TYPE.colorize(@options[:sev_colors][l.TYPE]) : l.TYPE
        l
      end
      # show newest last
      sorted_logs = logs.sort_by {|l| l.CREATED }
      tag_width = sorted_logs.map{|l| l.ASSET_TAG.length}.max
      sev_width = sorted_logs.map{|l| l.TYPE.length}.max
      time_width = sorted_logs.map{|l| l.CREATED.length}.max
      creator_width = sorted_logs.map{|l| l.CREATED_BY.length}.max
      sorted_logs.each do |l|
        puts "%-#{time_width}s: %-#{creator_width}s %-#{sev_width}s %-#{tag_width}s %s" % [l.CREATED, l.CREATED.BY, l.TYPE, l.ASSET_TAG, l.MESSAGE]
      end
    end

    def grab_logs
      if @options[:tags].empty?
        begin
          collins.all_logs(@search_opts)
        rescue => e
          $stderr.puts "Unable to fetch logs:".colorize(@options[:sev_colors]['WARNING']) + " #{e.message}"
          []
        end
      else
        @options[:tags].flat_map do |t|
          begin
            collins.logs(t, @search_opts)
          rescue => e
            $stderr.puts "Unable to fetch logs for #{t}:".colorize(@options[:sev_colors]['WARNING']) + " #{e.message}"
            []
          end
        end
      end
    end

  end
end

