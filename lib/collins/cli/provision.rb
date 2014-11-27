require 'collins-cli'
require 'etc'

#TODO help should be an action done in run

module Collins::CLI
  class Provision
    include Mixins
    PROG_NAME = 'collins provision'
    DEFAULT_OPTIONS = {
      :timeout => 120,
      :provision => { }
    }

    attr_reader :options

    def initialize
      @options = DEFAULT_OPTIONS.clone
      @parsed, @validated = false, false
      @options[:build_contact] = Etc.getlogin
      @parser = nil
    end

    def parse!(argv = ARGV)
      @parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options]"
        #TODO -s to show provisoining_profiles
        opts.separator ""
        opts.on('-n','--nodeclass NODECLASS',String,"Nodeclass to provision as. (Required)") {|v| @options[:provision][:nodeclass] = v }
        opts.on('-p','--pool POOL',String,"Provision with pool POOL.") {|v| @options[:provision][:pool] = v }
        opts.on('-r','--role ROLE',String,"Provision with primary role ROLE.") {|v| @options[:provision][:primary_role] = v }
        opts.on('-R','--secondary-role ROLE',String,"Provision with secondary role ROLE.") {|v| @options[:provision][:secondary_role] = v }
        opts.on('-s','--suffix SUFFIX',String,"Provision with suffix SUFFIX.") {|v| @options[:provision][:suffix] = v }
        opts.on('-a','--activate',"Activate server on provision (useful with SL plugin) (Default: ignored)") {|v| @options[:provision][:activate] = true }
        opts.on('-b','--build-contact USER',String,"Build contact. (Default: #{@options[:build_contact]})") {|v| @options[:build_contact] = v }

        opts.separator ""
        opts.separator "General:"
        opts.on('-t','--tags TAG[,...]',Array,"Tags to work on, comma separated") {|v| @options[:tags] = v.map(&:to_sym)}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| @options[:config] = v}
        opts.on('-h','--help',"Help") {puts opts ; exit 0}

        opts.separator ""
        opts.separator "Examples:\n  Provision some machines:\n    collins find -Sunallocated -arack_position:716|#{PROG_NAME} -P -napiwebnode6 -RALL"
      end.parse!(argv)

      if @options[:tags].nil? or @options[:tags].empty?
        # read tags from stdin. first field on the line is the tag
        input = ARGF.readlines
        @options[:tags] = input.map{|l| l.split(/\s+/)[0] rescue nil}.compact.uniq
      end
      @parsed = true
      self
    end

    def validate!
      raise "You need to specify at least a nodeclass when provisioning" if options[:provision][:nodeclass].nil?
      self
    end

    def run!
      action_successes = []
      options[:tags].each do |t|
        action_string = "#{t} provisioning with #{options[:provision].map{|k,v| "#{k}:#{v}"}.join(" ")} by #{options[:build_contact]}... "
        printf action_string
        begin
          res = collins.provision(t, options[:provision][:nodeclass], options[:build_contact], options[:provision])
          puts (res ? SUCCESS : ERROR )
          action_successes << res
        rescue => e
          puts "#{ERROR} (#{e.message})"
          action_successes << false
        end
      end
      action_successes.all?
    end

  end
end

