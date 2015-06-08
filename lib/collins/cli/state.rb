require 'collins-cli'

module Collins::CLI
  class State

    include Mixins
    include Formatter
    PROG_NAME = 'collins state'
    OPTIONS_DEFAULTS = {
      :format => :table,
      :separator => "\t",
      :timeout => 120,
      :show_header => false,
      :config => nil
    }
    attr_reader :options

    def initialize
      @options = OPTIONS_DEFAULTS.clone
      @validated = false
      @parsed = false
    end

    def parse!(argv = ARGV)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        opts.on('-l','--list',"List states.") { @options[:mode] = :list }
        opts.on('-h','--help',"Help") {puts opts ; exit 0}
        opts.separator ""
        opts.separator "Table formatting:"
        opts.on('-H','--show-header',"Show header fields in output") {options[:show_header] = true}
        opts.on('-f','--field-separator SEPARATOR',String,"Separator between columns in output (Default: #{options[:separator]})") {|v| options[:separator] = v}
        opts.separator ""
        opts.separator "Extra options:"
        opts.on('--timeout SECONDS',Integer,"Timeout in seconds (0 == forever)") {|v| options[:timeout] = v}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| options[:config] = v}
        opts.separator ""
        opts.separator "Examples:"
        opts.separator <<_EOF_
  Show states and statuses:
    #{PROG_NAME} --list
_EOF_
      end.parse!(argv)
      @parsed = true
      self
    end

    def validate!
      raise "See --help for #{PROG_NAME} usage" if options[:mode].nil?
      @validated = true
      self
    end

    def run!
      exit_clean = true
      case @options[:mode]
      when :list
        states = collins.state_get_all
        format_states(states, options)
      else
        raise "I dunno what you want me to do! See #{PROG_NAME} --help"
      end
      exit_clean

    end

  end
end

