$:.unshift(File.dirname(__FILE__))

require 'collins_auth'
require 'yaml'
require 'optparse'
require 'colorize'

['log','helper','mixins'].each {|r| require File.join('collins/cli',r) }

module Collins ; module CLI ; end ; end

