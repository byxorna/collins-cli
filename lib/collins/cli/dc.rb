require 'collins-cli'
require 'fileutils'
require 'optparse/uri'
require 'etc'
require 'io/console'

module Collins::CLI
  class DC
    include Mixins
    include Formatter
    PROG_NAME = 'collins dc'
    DEFAULT_CONFIG_PATH = '~/.collins.yml'

    DEFAULT_OPTIONS = {
      :show_current => true, # used for :list
      :mode         => :show,
      :dc           => nil, # used for :set
      :timeout      => 120, # used for :new
      :host         => nil, # used for :new
      :pw           => nil, # used for :new
      :user         => nil, # used for :new
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
        opts.separator "New Configuration:"
        opts.on('-n', '--new DATACENTER', String, "Create a new configuration file for DATACENTER at #{DEFAULT_CONFIG_PATH}.DATACENTER") {|v| @options[:dc] = v ; @options[:mode] = :new}
        opts.on('-H', '--host URI', URI, 'Use URI for host when setting up new datacenter') {|v| @options[:host] = v}
        opts.on('-u', '--username USER', String, 'Use USER for username when setting up new datacenter') {|v| @options[:user] = v}
        opts.on('-p', '--password PASSWORD', String, 'Use PASSWORD for password when setting up new datacenter') {|v| @options[:pw] = v}

        opts.separator ""
        opts.separator "List:"
        opts.on('-l', '--list', 'List configured collins instances') {|v| @options[:mode] = :list}

        opts.separator ""
        opts.separator "General:"
        opts.on('-h','--help',"Help") {@options[:mode] = :help}

        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  Show current Collins instance in use"
        opts.separator "    #{PROG_NAME}"
        opts.separator "  Set current Collins instance to jfk01"
        opts.separator "    #{PROG_NAME} jfk01"
        opts.separator "  List all Collins instances configured"
        opts.separator "    #{PROG_NAME} -l"
        opts.separator "  Set up new Collins instance for sfo01"
        opts.separator "    #{PROG_NAME} --new sfo01 --host https://collins.sfo01.company.net"
        opts.separator "  Iterate over all instances and find assets"
        opts.separator "    for dc in $(#{PROG_NAME} -l) ; do #{PROG_NAME} $dc ; collins find -p DEVELOPMENT ; done"
      end
      @parser.parse!(argv)
      #TODO(gabe): if user not specified, read from env or something

      # if mode is :show (default), and an argument was provided in argv, set mode to :set
      if @options[:mode] == :show && argv.length > 0
        @options[:mode] = :set
        @options[:dc] = argv.first
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
        puts default_datacenter
      when :set
        dc = @options[:dc]
        if !configured_datacenters.include?(dc)
          raise "No Collins configuration for datacenter #{dc.inspect} found. Perhaps you want to create it with '#{PROG_NAME} --new #{dc}'?"
        end
        set_default_datacenter(dc)
      when :list
        dcs = configured_datacenters
        default = default_datacenter
        dcs.each do |dc|
          if dc == default && @options[:show_current]
            puts "#{dc} *"
          else
            puts dc
          end
        end
      when :new
        # check if dc already exists
        dc = @options[:dc]
        if configured_datacenters.include? dc
          raise "Unable to create new configuration for #{dc}: Configuration already exists at #{DEFAULT_CONFIG_PATH}.#{@options[:dc]}"
        end

        uri = @options[:host]
        if uri.nil?
          print "Enter Collins URI for #{dc} (i.e. https://collins.#{dc}.company.net): "
          x = gets
          uri = URI.parse(x.strip)
        end

        user = @options[:user]
        if user.nil?
          default = Etc.getlogin
          print "Enter username (default: #{default}): "
          x = gets.strip
          if x.empty?
            user = default
          else
            user = x
          end
        end

        pw = @options[:pw]
        if pw.nil?
          print "Enter password: "
          pw = STDIN.noecho(&:gets).chomp
          print "\n"
        end
        create_new_datacenter(dc, uri, user, pw, @options[:timeout])

        # if this is the only DC, use it
        has_default_dc = File.symlink?(File.expand_path(DEFAULT_CONFIG_PATH)) rescue false
        if !has_default_dc
          set_default_datacenter(dc)
          puts "Automatically selected #{dc.inspect} as the current datacenter with '#{PROG_NAME} #{dc}'"
        else
          puts "Now, select the Collins instance #{dc.inspect} with '#{PROG_NAME} #{dc}' to access Collins"
        end
      end
      success
    end

    def configured_datacenters
      # return list of dc names, followed by an asterisk if default?
      files = Dir.glob(File.expand_path(DEFAULT_CONFIG_PATH + ".*"))
      files.map do |f|
        File.basename(f).split('.').last
      end.sort
    end

    def set_default_datacenter dc
      ln = File.expand_path(DEFAULT_CONFIG_PATH)
      if File.exist?(ln) && !File.symlink?(ln)
        raise "Unable to set config to use #{dc}: #{ln} is not a symlink, which means #{PROG_NAME.inspect} is not managing this configuration"
      end
      FileUtils.ln_sf(File.expand_path("~/.collins.yml.#{dc}"), File.expand_path(DEFAULT_CONFIG_PATH))
    end

    def default_datacenter
      def_cfg = File.expand_path(DEFAULT_CONFIG_PATH)
      if !File.symlink?(def_cfg)
        raise "Unable to determine default Collins datacenter: #{def_cfg} is not a symlink, which means #{PROG_NAME.inspect} is not managing this configuration"
      end
      target = File.basename(File.readlink(def_cfg))
      if target =~ /^\.collins\.yml\.([A-Za-z0-9\-_]+)$/
        return $1
      else
        raise "Unable to determine datacenter from target config #{target}; does not match .collins.yml.$DATACENTER"
      end
    end

    def create_new_datacenter dc, uri, user, pw, t
      o = {
        host: uri.to_s,
        username: user,
        timeout: t
      }
      o[:password] = pw unless pw.nil? || pw.empty?
      File.open(File.expand_path("#{DEFAULT_CONFIG_PATH}.#{dc}"), 'w', 0600) do |f|
        f.puts o.to_yaml
      end
    end

  end
end

