require 'collins-cli'

module Collins::CLI
  class IPAM
    include Mixins
    include Formatter
    PROG_NAME = 'collins ipam'

    DEFAULT_OPTIONS = {
      :timeout => 120,
      :mode => nil,
      :show_header => false,
      :num => 1,
      :tags => [],
    }

    attr_reader :options, :parser

    def initialize
      @options = DEFAULT_OPTIONS.clone
      @parsed, @validated = false, false
      @parser = nil
    end

    def parse!(argv = ARGV)
      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        opts.separator ""
        opts.on('-s','--show-pools',"Show IP pools") {|v| @options[:mode] = :show }
        opts.on('-H','--show-header',"Show header fields in --show-pools output") {|v| @options[:show_header] = true }
        opts.on('-a','--allocate POOL',String,"Allocate addresses in POOL") {|v| @options[:mode] = :allocate ; @options[:pool] = v }
        opts.on('-n','--number [NUM]',Integer,"Allocate NUM addresses (Defaults to 1 if omitted)") {|v| @options[:num] = v || 1 }
        opts.on('-d','--delete [POOL]',String,"Delete addresses in POOL. Deletes ALL addresses if POOL is omitted") {|v| @options[:mode] = :delete ; @options[:pool] = v }

        opts.separator ""
        opts.separator "General:"
        opts.on('-t','--tags TAG[,...]',Array,"Tags to work on, comma separated") {|v| @options[:tags] = v.map(&:to_sym)}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| @options[:config] = v}
        opts.on('-h','--help',"Help") {@options[:mode] = :help}

        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  Show configured IP address pools:"
        opts.separator "    #{PROG_NAME} --show-pools -H"
        opts.separator "  Allocate 2 IPs on each asset"
        opts.separator "    #{PROG_NAME} -t 001234,003456,007895 -a DEV_POOL -n2"
        opts.separator "  Deallocate IPs in DEV_POOL pool on assets:"
        opts.separator "    #{PROG_NAME} -t 001234,003456,007895 -d DEV_POOL"
        opts.separator "  Deallocate ALL IPs on assets:"
        opts.separator "    #{PROG_NAME} -t 001234,003456,007895 -d"
      end
      @parser.parse!(argv)

      # only read tags from ARGF if we are going to do something with the tags
      if [:allocate,:delete].include? options[:mode] && (options[:tags].nil? or options[:tags].empty?)
        # read tags from stdin. first field on the line is the tag
        input = ARGF.readlines
        @options[:tags] = input.map{|l| l.split(/\s+/)[0] rescue nil}.compact.uniq
      end
      @parsed = true
      self
    end

    def validate!
      raise "You need to tell me to do something!" if @options[:mode].nil?
      raise "No asset tags found via ARGF" if [:allocate,:delete].include?(options[:mode]) && (options[:tags].nil? or options[:tags].empty?)
      @validated = true
      self
    end

    def run!
      raise "Options not yet parsed with #parse!" unless @parsed
      raise "Options not yet validated with #validate!" unless @validated
      success = true
      case options[:mode]
      when :help
        puts parser
      when :show
        pools = collins.ipaddress_pools
        format_pools(pools, :show_header => options[:show_header])
      when :allocate
        options[:tags].each do |t|
          res = api_call("allocating #{options[:num]} IP in #{options[:pool]}",:ipaddress_allocate!,t,options[:pool],options[:num]) do |addresses|
            "Allocated #{addresses.map(&:address).join(' ')}"
          end
          success = false unless res
        end
      when :delete
        options[:tags].each do |t|
          res = api_call("deleting all IPs#{" in #{options[:pool]}" unless options[:pool].nil?}",:ipaddress_delete!,t,options[:pool]) { |count| "Deleted #{count} IPs" }
          success = false unless res
        end
      end
      success
    end

  end
end

