require 'collins-cli'

#TODO: querying for :status or :state with -a status:maintenance doesnt play nice with -Smaintenance,allocated
#TODO: we construct the query for states and statuses only from the parameters to --status (ignoring any -a attributes)

module Collins::CLI
  class Find
    include Mixins
    include Formatter   # how to display assets

    PROG_NAME = 'collins-find'
    QUERY_DEFAULTS = {
      :operation => 'AND',
      :size => 9999,
    }
    OPTION_DEFAULTS = {
      :format          => :table,           # how to display the results
      :separator        => "\t",
      :attributes       => {},            # additional attributes to query for
      :columns          => [:tag, :hostname, :nodeclass, :status, :pool, :primary_role, :secondary_role],
      :column_override  => [],       # if set, these are the columns to display
      :timeout          => 120,
      :show_header      => false,        # if the header for columns should be displayed
      :config           => nil           # collins config to give to setup_client
    }

    attr_reader :options

    def initialize
      @parsed, @validated = false, false
      @query_opts = QUERY_DEFAULTS.clone
      @search_attrs = {}
      @options = OPTION_DEFAULTS.clone
    end

    def parse!(argv = [])
      raise "See --help for #{PROG_NAME} usage" if argv.empty?
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROG_NAME} [options] [hostnamepattern]"
        opts.separator "Query options:"
        opts.on('-t','--tag TAG[,...]',Array, "Assets with tag[s] TAG") {|v| search_attrs[:tag] = v}
        opts.on('-T','--type TYPE',String, "Only show assets with type TYPE") {|v| search_attrs[:type] = v}
        opts.on('-n','--nodeclass NODECLASS[,...]',Array, "Assets in nodeclass NODECLASS") {|v| search_attrs[:nodeclass] = v}
        opts.on('-p','--pool POOL[,...]',Array, "Assets in pool POOL") {|v| search_attrs[:pool] = v}
        opts.on('-s','--size SIZE',Integer, "Number of assets to return (Default: #{query_opts[:size]})") {|v| query_opts[:size] = v}
        opts.on('-r','--role ROLE[,...]',Array,"Assets in primary role ROLE") {|v| search_attrs[:primary_role] = v}
        opts.on('-R','--secondary-role ROLE[,...]',Array,"Assets in secondary role ROLE") {|v| search_attrs[:secondary_role] = v}
        opts.on('-i','--ip-address IP[,...]',Array,"Assets with IP address[es]") {|v| search_attrs[:ip_address] = v}
        opts.on('-S','--status STATUS[:STATE][,...]',Array,"Asset status (and optional state after :)") do |v|
          # in order to know what state was paired with what status, lets store the original params
          # so the query constructor can create the correct CQL query
          options[:status_state] = v
          search_attrs[:status], search_attrs[:state] = v.inject([[],[]]) do |memo,s|
            status,state = s.split(':')
            memo[0] << status.upcase if not status.nil? and not status.empty?
            memo[1] << state.upcase if not state.nil? and not state.empty?
            memo
          end
        end
        opts.on('-a','--attribute attribute[:value[,...]]',String,"Arbitrary attributes and values to match in query. : between key and value") do |x|
          x.split(',').each do |p|
            a,v = p.split(':')
            a = a.to_sym
            if not search_attrs[a].nil? and not search_attrs[a].is_a? Array
              # its a single value, turn it into an array
              search_attrs[a] = [search_attrs[a]]
            end
            if search_attrs[a].is_a? Array
              # already multivalue, append
              search_attrs[a] << v
            else
              search_attrs[a] = v
            end
          end
        end

        opts.separator ""
        opts.separator "Table formatting:"
        opts.on('-H','--show-header',"Show header fields in output") {options[:show_header] = true}
        opts.on('-c','--columns ATTRIBUTES',Array,"Attributes to output as columns, comma separated (Default: #{options[:columns].map(&:to_s).join(',')})") {|v| options[:column_override] = v.map(&:to_sym)}
        opts.on('-x','--extra-columns ATTRIBUTES',Array,"Show these columns in addition to the default columns, comma separated") {|v| options[:columns].push(v.map(&:to_sym)).flatten! }
        opts.on('-f','--field-separator SEPARATOR',String,"Separator between columns in output (Default: #{options[:separator]})") {|v| options[:separator] = v}

        opts.separator ""
        opts.separator "Robot formatting:"
        opts.on('-l','--link',"Output link to assets found in web UI") {options[:format] = :link}
        opts.on('-j','--json',"Output results in JSON (NOTE: This probably wont be what you expected)") {options[:format] = :json}
        opts.on('-y','--yaml',"Output results in YAML") {options[:format] = :yaml}

        opts.separator ""
        opts.separator "Extra options:"
        opts.on('--expire SECONDS',Integer,"Timeout in seconds (0 == forever)") {|v| options[:timeout] = v}
        opts.on('-C','--config CONFIG',String,'Use specific Collins config yaml for Collins::Client') {|v| options[:config] = v}
        opts.on('-h','--help',"Help") {puts opts ; exit 0}

        opts.separator ""
        opts.separator <<_EXAMPLES_
Examples:
    Query for devnodes in DEVEL pool that are VMs
      cf -n develnode -p DEVEL
    Query for asset 001234, and show its system_password
      cf -t 001234 -x system_password
    Query for all decommissioned VM assets
      cf -a is_vm:true -S decommissioned
    Query for hosts matching hostname '^web6-'
      cf ^web6-
    Query for all develnode6 nodes with a value for PUPPET_SERVER
      cf -n develnode6 -a puppet_server -H
_EXAMPLES_
      end.parse!(argv)
      # hostname is the final option, no flags
      search_attrs[:hostname] = argv.shift
      @parsed = true
    end

    def validate!
      raise "Options not yet parsed with #parse!" unless @parsed
      # fix bug where assets wont get found if they dont have that meta attribute
      search_attrs.delete(:hostname) if search_attrs[:hostname].nil?
      # for any search attributes, lets not pass arrays of 1 element
      # as that will confuse as_query?
      search_attrs.each do |k,v|
        if v.is_a? Array
          search_attrs[k] = v.first if v.length == 1
          search_attrs[k] = nil if v.empty?
        end
      end

      # merge search_attrs into query
      if as_query?(search_attrs)
        query_opts[:query] = convert_to_query(query_opts[:operation], search_attrs, options)
        #puts "Query: #{query_opts[:query]}"
      else
        query_opts.merge!(search_attrs)
      end
    end

    def run!
      begin
        assets = collins.find(query_opts)
      rescue => e
        abort "Error querying collins: #{e.message}"
      end
      format_assets(assets, options[:display])
    end

  end
end


