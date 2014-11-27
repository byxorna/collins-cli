require 'collins-cli'

module Collins::CLI
  class Power
    include Mixins
    PROG_NAME = 'collins power'
    ALLOWABLE_POWER_ACTIONS = ['reboot','rebootsoft','reboothard','on','off','poweron','poweroff','identify']
    DEFAULT_OPTIONS = {
      :timeout => 120,
    }

    attr_reader :options

    def initialize
      @options = DEFAULT_OPTIONS.clone
      @parsed, @validated = false, false
      @parser = nil
    end

    def parse!(argv = ARGV)
      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        opts.separator ""
        opts.on('-s','--status',"Show IPMI power status") {|v| @options[:mode] = :status }
        opts.on('-p','--power ACTION',String,"Perform IPMI power ACTION") {|v| @options[:mode] = :power ; @options[:power] = v.downcase }

        opts.separator ""
        opts.separator "General:"
        opts.on('-t','--tags TAG[,...]',Array,"Tags to work on, comma separated") {|v| @options[:tags] = v.map(&:to_sym)}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| @options[:config] = v}
        opts.on('-h','--help',"Help") {puts opts ; exit 0}

        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  Reset some machines:"
        opts.separator "    #{PROG_NAME} -t 001234,003456,007895 -p reboot"
      end.parse!(argv)

      # convert what we allow to be specified to what collins::power allows
      @options[:power] = 'rebootsoft' if @options[:power] == 'reboot'

      if options[:tags].nil? or options[:tags].empty?
        # read tags from stdin. first field on the line is the tag
        input = ARGF.readlines
        @options[:tags] = input.map{|l| l.split(/\s+/)[0] rescue nil}.compact.uniq
      end
      @parsed = true
      self
    end

    def validate!
      raise "You need to tell me to do something!" if @options[:mode].nil?
      if options[:mode] == :power
        abort "Unknown power action #{options[:power]}, expecting one of #{ALLOWABLE_POWER_ACTIONS.join(',')}" unless ALLOWABLE_POWER_ACTIONS.include? options[:power]
        # TODO this arguably shouldnt be in validate. Maybe #parse!?
        @options[:power] = Collins::Power.normalize_action @options[:power]
      end
      self
    end

    def run!
      success = true
      options[:tags].each do |t|
        case options[:mode]
        when :status
          res = api_call("power status is %s",:power_status,t)
          success = false if !res
        when :power
          success &&= api_call("performing #{options[:power]}", :power!, t, options[:power])
        end
      end
      success
    end

  end
end

