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

  def api_call desc, method, *varargs
    success,message = begin
      [collins.send(method,*varargs),nil]
    rescue => e
      [false,e.message]
    end
    puts "#{success ? SUCCESS : ERROR}: #{desc}#{message.nil? ? nil : " (%s)" % e.message}"
    success
  end

end ; end ; end
