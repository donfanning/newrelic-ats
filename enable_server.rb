#!/usr/local/rvm/rubies/ext-ruby-2.0.0-p598/bin/ruby

require 'trollop'
require 'mysql2'
require 'hirb'

db = Mysql2::Client.new(:host => 'localhost', :username => 'newrelic', :password => 'newrelic', :database => 'newrelic_ats')

opts = Trollop::options do
  opt :enable, "Enable polling on server"
  opt :disable, "Disable polling on server"
  opt :list, "List servers in database", :default => true

  banner <<-EOS
simple program to enable or disable a server in the database whereupon is checked by new relic ats scripts as to whether or not to poll from.

Usage:
  enable_server [options] <servername>
where [options] are:
EOS
    
end

##p opts 

opts.each do |k,v|
  #puts "#{k} #{v}"
end

if opts[:disable]
    opts[:list] = false
end

if opts[:enable]
    opts[:list]	= false
end

if opts[:list]
    puts "Enabled Servers:"
    sql = "SELECT * FROM ats where enabled = 1"
    srvlist = db.query(sql, :as => :array)
    puts Hirb::Helpers::AutoTable.render(srvlist)
    puts ""
    puts "Disabled Servers:"
    sql = "SELECT * FROM ats where enabled = 0"
    srvlist = db.query(sql, :as => :array)
    puts Hirb::Helpers::AutoTable.render(srvlist)
    puts
    puts "Use the '-h' option for help"
end

if opts[:disable]
    puts
    puts "Disabling #{ARGV[0]}"
    sql = "UPDATE ats SET enabled = false WHERE servername like '%#{ARGV[0]}%'"
    #puts sql
    output = db.query(sql)
    puts ""
    puts "Disabled Servers:"
    sql = "SELECT * FROM ats where enabled = 0"
    srvlist = db.query(sql, :as => :array)
    puts Hirb::Helpers::AutoTable.render(srvlist)
end

if opts[:enable]
    puts
    puts "Enabling #{ARGV[0]}"
    sql = "UPDATE ats SET enabled = true WHERE servername like '%#{ARGV[0]}%'"
    #puts sql
    output = db.query(sql)
    puts ""
    puts "Disabled Servers:"
    sql = "SELECT * FROM ats where enabled = 0"
    srvlist = db.query(sql, :as => :array)
    puts Hirb::Helpers::AutoTable.render(srvlist)
end
