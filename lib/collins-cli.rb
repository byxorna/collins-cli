$:.unshift(File.dirname(__FILE__))

require 'collins_auth'
require 'yaml'
require 'json'
require 'optparse'
require 'colorize'

['mixins','formatter','log','modify','find','power','provision','ipam'].
  each {|r| require File.join('collins/cli',r) }

module Collins ; module CLI ; end ; end

