require 'collins-cli'

module Collins ; module CLI ; module Mixins
  COLORS = {
        'EMERGENCY'     => {:color => :red, :background => :light_blue},
        'ALERT'         => {:color => :red},
        'CRITICAL'      => {:color => :black, :background => :red},
        'ERROR'         => {:color => :red},
        'WARNING'       => {:color => :yellow},
        'NOTICE'        => {},
        'INFORMATIONAL' => {:color => :green},
        'SUCCESS'       => {:color => :green},
        'DEBUG'         => {:color => :blue},
        'NOTE'          => {:color => :light_cyan},
      }
  SUCCESS = "SUCCESS".colorize(COLORS['SUCCESS'])
  ERROR   = "ERROR".colorize(COLORS['ERROR'])

  def collins
    begin
      @collins ||= Collins::Authenticator.setup_client timeout: @options[:timeout], config_file: @options[:config], prompt: true
    rescue => e
      raise "Unable to set up Collins client! #{e.message}"
    end
  end

  def api_call desc, method, tag, *varargs, &block
    printf "%s %s... " % [tag, desc]
    result,message = begin
      [collins.send(method,tag,*varargs),nil]
    rescue => e
      [false,e.message]
    end
    if result && block_given?
      # if the call was a success, let the caller format the response
      formatted_result = yield result
    end
    str = "#{result ? SUCCESS : ERROR}#{formatted_result.nil? ? '' : " (#{formatted_result})"}#{message.nil? ? nil : " (%s)" % e.message}"
    puts str
    result
  end

  def as_query?(attrs)
    attrs.any?{|k,v| v.is_a? Array}
  end

  def convert_to_query(op, attrs, options)
    # we want to support being able to query -Smaintenance:noop,:running,:provisioning_problem
    # and not have the states ored together. Handle status/state pairs separately
    basic_query = attrs.reject {|k,v| [:status,:state].include?(k)}.map do |k,v|
      next if v.nil?
      if v.is_a? Array
        "(" + v.map{|x| "#{k} = #{x}"}.join(' OR ') + ")"
      else
        "#{k} = #{v}"
      end
    end.compact.join(" #{op} ")
    # because they are provided in pairs, lets handle them together
    # create the (( STATUS = maintenance AND STATE = noop) OR (STATE = provisioning_problem)) query
    if options[:status_state]
      status_query = options[:status_state].flat_map do |ss|
        h = {}
        h[:status], h[:state] = ss.split(':')
        h[:status] = nil if h[:status].nil? or h[:status].empty?
        h[:state] = nil if h[:state].nil? or h[:state].empty?
        "( " + h.map {|k,v| v.nil? ? nil : "#{k.to_s.upcase} = #{v}"}.compact.join(" AND ") + " )"
      end.compact.join(' OR ')
      status_query = "( #{status_query} )"
    end
    [basic_query,status_query].reject {|q| q.nil? or q.empty?}.join(" #{op} ")
  end

end ; end ; end
