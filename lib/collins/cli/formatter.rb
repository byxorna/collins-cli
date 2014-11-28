require 'collins-cli'

module Collins::CLI::Formatter
  FORMATTING_DEFAULTS = {
    :format           => :table,           # how to display the results
    :separator        => "\t",
    :columns          => [:tag, :hostname, :nodeclass, :status, :pool, :primary_role, :secondary_role],
    :column_override  => [],       # if set, these are the columns to display
    :show_header      => false,        # if the header for columns should be displayed
  }
  ADDRESS_POOL_COLUMNS = [:name, :network, :start_address, :specified_gateway, :gateway, :broadcast, :possible_addresses]

  def format_pools(pools, opts = {})
    if pools.length > 0
      opts = FORMATTING_DEFAULTS.merge(opts)
      # map the hashes into openstructs that will respond to #send(:name)
      ostructs = pools.map { |p| OpenStruct.new(Hash[p.map {|k,v| [k.downcase,v]}]) }
      display_as_table(ostructs, ADDRESS_POOL_COLUMNS, opts[:separator], opts[:show_header])
    else
      raise "No pools found"
    end
  end

  def format_assets(assets, opts = {})
    opts = FORMATTING_DEFAULTS.merge(opts)
    if assets.length > 0
      case opts[:format]
      when :table
        # if the user passed :column_override, respect that absolutely. otherwise, the columns to display
        # should be opts[:columns] + any extra attributes queried for. this way ```cf -c hostname -a is_vm:true```
        # wont return 2 columns; only the one you asked for
        columns = if opts[:column_override].empty?
                    opts[:columns].concat(search_attrs.keys).compact.uniq
                  else
                    opts[:column_override]
                  end
        display_as_table(assets,columns,opts[:separator],opts[:show_header])
      when :link
        display_as_link assets, collins
      when :json,:yaml
        display_as_robot_talk(assets,opts[:format])
      else
        raise "I don't know how to display assets in #{opts[:format]} format!"
      end
    else
      raise "No assets found"
    end
  end

  def display_as_robot_talk(assets, format = :json)
    puts assets.send("to_#{format}".to_sym)
  end
  def display_as_table(assets, columns, separator, show_header = false)
    # lets figure out how wide each column is, including header
    column_width_pairs = columns.map do |column|
      # grab all attributes == column and figure out max width
      width = assets.map{|a| (column == :state) ?  a.send(column).label.to_s.length : a.send(column).to_s.length}.max
      width = [width, column.to_s.length].max if show_header
      [column,width]
    end
    column_width_map = Hash[column_width_pairs]
    if show_header
      $stderr.puts column_width_map.map{|c,w| "%-#{w}s" % c}.join(separator)
    end
    assets.each do |a|
      puts column_width_map.map {|c,w| v = (c == :state) ?  a.send(c).label : a.send(c) ; "%-#{w}s" % v }.join(separator)
    end
  end
  def display_as_link assets, client
    assets.each do |a|
      puts "#{client.host}/asset/#{a.tag}"
    end
  end
end
