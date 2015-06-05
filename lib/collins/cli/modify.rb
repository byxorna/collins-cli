require 'collins-cli'

module Collins::CLI
  class Modify

    include Mixins

    VALID_STATUSES = ["ALLOCATED","CANCELLED","DECOMMISSIONED","INCOMPLETE","MAINTENANCE","NEW","PROVISIONED","PROVISIONING","UNALLOCATED"]
    #TODO: this shouldnt be hardcoded. we should pull this from the API instead?
    # should elegantly support user-defined states without changing this script
    LOG_LEVELS = Collins::Api::Logging::Severity.constants.map(&:to_s)
    OPTIONS_DEFAULTS = {
      :query_size => 9999,
      :attributes => {},
      :delete_attributes => [],
      :log_level  => 'NOTE',
      :timeout    => 120,
      :config     => nil
    }
    PROG_NAME = 'collins modify'

    attr_reader :options

    def initialize
      @options = OPTIONS_DEFAULTS.clone
      @validated = false
      @parsed = false
    end

    def parse!(argv = ARGV)
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        opts.on('-a','--set-attribute attribute:value',String,"Set attribute=value. : between key and value. attribute will be uppercased.") do |x|
          if not x.include? ':'
            puts '--set-attribute requires attribute:value, missing :value'
            puts opts.help
            exit 1
          end
          a,*v = x.split(':')
          # handle values with : in them :)
          @options[:attributes][a.upcase.to_sym] = v.join(":")
        end
        opts.on('-d','--delete-attribute attribute',String,"Delete attribute.") {|v| @options[:delete_attributes] << v.to_sym }
        opts.on('-S','--set-status status[:state]',String,'Set status (and optionally state) to status:state. Requires --reason') do |v|
          status,state = v.split(':')
          @options[:status] = status.upcase if not status.nil? and not status.empty?
          @options[:state] = state.upcase if not state.nil? and not state.empty?
        end
        opts.on('-r','--reason REASON',String,"Reason for changing status/state.") {|v| @options[:reason] = v }
        opts.on('-l','--log MESSAGE',String,"Create a log entry.") do |v|
          @options[:log_message] = v
        end
        opts.on('-L','--level LEVEL',String, LOG_LEVELS + LOG_LEVELS.map(&:downcase),"Set log level. Default level is #{@options[:log_level]}.") do |v|
          @options[:log_level] = v.upcase
        end
        opts.on('-t','--tags TAGS',Array,"Tags to work on, comma separated") {|v| @options[:tags] = v.map(&:to_sym)}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| @options[:config] = v}
        opts.on('-h','--help',"Help") {puts opts ; exit 0}
        opts.separator ""
        opts.separator "Allowed values (uppercase or lowercase is accepted):"
        opts.separator <<_EOF_
  Status:State (-S,--set-status):
    See \`collins state --list\`
  Log levels (-L,--level):
    #{LOG_LEVELS.join(', ')}
_EOF_
        opts.separator ""
        opts.separator "Examples:"
        opts.separator <<_EOF_
  Set an attribute on some hosts:
    #{PROG_NAME} -t 001234,004567 -a my_attribute:true
  Delete an attribute on some hosts:
    #{PROG_NAME} -t 001234,004567 -d my_attribute
  Delete and add attribute at same time:
    #{PROG_NAME} -t 001234,004567 -a new_attr:test -d old_attr
  Set machine into maintenace noop:
    #{PROG_NAME} -t 001234 -S maintenance:maint_noop -r "I do what I want"
  Set machine back to allocated:
    #{PROG_NAME} -t 001234 -S allocated:running -r "Back to allocated"
  Set machine back to new without setting state:
    #{PROG_NAME} -t 001234 -S new -r "Dunno why you would want this"
  Create a log entry:
    #{PROG_NAME} -t 001234 -l'computers are broken and everything is horrible' -Lwarning
  Read from stdin:
    collins find -n develnode | #{PROG_NAME} -d my_attribute
    collins find -n develnode -S allocated | #{PROG_NAME} -a collectd_version:5.2.1-52
    echo -e "001234\\n001235\\n001236"| #{PROG_NAME} -a test_attribute:'hello world'
_EOF_
      end.parse!(argv)
      if options[:tags].nil? or options[:tags].empty?
        # read tags from stdin. first field on the line is the tag
        input = ARGF.readlines
        @options[:tags] = input.map{|l| l.split(/\s+/)[0] rescue nil}.compact.uniq
      end
      @parsed = true
      self
    end

    def validate!
      raise "See --help for #{PROG_NAME} usage" if options[:attributes].empty? and options[:delete_attributes].empty? and options[:status].nil? and options[:log_message].nil?
      raise "You need to provide a --reason when changing asset states!" if not options[:status].nil? and options[:reason].nil?
      #TODO this is never checked because we are making option parser vet our options for levels. Catch OptionParser::InvalidArgument?
      raise "Log level #{options[:log_level]} is invalid! Use one of #{LOG_LEVELS.join(', ')}" unless Collins::Api::Logging::Severity.valid?(options[:log_level])

      unless options[:status].nil?
        raise "Invalid status #{options[:status]} (Should be in #{VALID_STATUSES.join(', ')})" unless VALID_STATUSES.include? options[:status]
      end


      @validated = true
      self
    end

    def run!
      exit_clean = true
      options[:tags].each do |t|
        if options[:log_message]
          exit_clean = api_call("logging #{options[:log_level].downcase} #{options[:log_message].inspect}", :log!, t, options[:log_message], options[:log_level]) && exit_clean
        end
        options[:attributes].each do |k,v|
          exit_clean = api_call("setting #{k}=#{v}", :set_attribute!, t, k, v) && exit_clean
        end
        options[:delete_attributes].each do |k|
          exit_clean = api_call("deleting #{k}", :delete_attribute!, t, k) && exit_clean
        end
        if options[:status]
          exit_clean = api_call("changing status to #{options[:status]}#{options[:state] ? ":#{options[:state]}" : ''}", :set_status!, t, :status => options[:status], :state => options[:state], :reason => options[:reason]) && exit_clean
        end
      end
      exit_clean
    end

  end
end

