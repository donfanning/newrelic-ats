require 'rubygems'
require 'chef'  
require "mysql"
require "rest-client"
require "json"
require "newrelic_plugin"
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

Chef::Config[:node_name]='username'
Chef::Config[:client_key]='/home/username/.chef/username.pem'
Chef::Config[:chef_server_url]="https://chef.server.com/organizations/myorg"     
$exclude_list = ['CHINA-ATS_A','CHINA-ATS_B']
$environment_list = ['PROD-ATS','S-ATS','PERF-ATS','STG-ATS']

system("rm Procfile")
system("touch Procfile")

def get_nodes
	db = Mysql.new 'localhost', 'newrelic', 'newrelic', 'newrelic_ats'
	environments = Chef::Environment.list('*')
	filtered_envs = Array.new
	environments.keys.each do |env|
	  unless $exclude_list.include?(env)
	  	filtered_envs << env
	  end
	end

	edited_envs = Array.new
	filtered_envs.each do |env|
		edited_envs << env unless env !~ /ATS/
	end
	@envs = Array.new
	@envs = edited_envs.uniq

	@nodes = Hash.new()
	@envs.sort.each do |env|
		if !env.include? "TEST"
		  meta_env = env[0..-3]
		else 
			meta_env = env
		end

		if !@nodes.has_value?(meta_env)
			query = Chef::Search::Query.new
			data = query.search('node', "chef_environment:#{meta_env}* AND role:ATS").first rescue []
			unless data.empty? or data.nil? 
				data.each do |node|
					nodename = node.name.to_s
					@nodes[nodename] = "#{meta_env}"
				end
			end
		end
	end
	@nodes.each { |k,v| 
		#puts "#{k} = #{v}"
		db.query("INSERT IGNORE INTO ats VALUES('#{k}','#{v}',true)")
	}
	db.close
end

def init_db
	db = Mysql.new 'localhost', 'newrelic', 'newrelic', 'newrelic_ats'
    db.query("DROP TABLE IF EXISTS ats")
    db.query("CREATE TABLE ats(servername TEXT, environment TEXT, enabled BOOLEAN)")
	db.query("DROP TABLE IF EXISTS ATS")
	$environment_list.each do |env|
		#puts env
		env.gsub! '-', '_'
		#puts env
		db.query("DROP TABLE IF EXISTS #{env}")
		db.query("CREATE TABLE #{env} (hash TEXT, value INT DEFAULT 0, servername TEXT, ats_stat TEXT, variable TEXT)")
	end
	$apistats_env_list.each do |env|
		env.gsub! '-', '_'
		db.query("DROP TABLE IF EXISTS #{env}")
		db.query("CREATE TABLE #{env} (statistic_name TEXT, statistic_value INT DEFAULT 0)")
	end
	db.query("DROP TABLE IF EXISTS apistats")
	db.query("CREATE TABLE apistats (server TEXT, url TEXT, target TEXT, magickey TEXT, statistic_name TEXT, statistic_value INT, variable TEXT)")
	db.close
end

def clean_server_name_for_db(servername)
	servername.chomp
  	sname_clean = servername;
	sname_clean = sname_clean.gsub /\./, '_'
	sname_clean = sname_clean.gsub /-/, '_'
	sname_clean = sname_clean.gsub /\:/, '_'
	return sname_clean
end

def clean_env_name_for_db(environment)
	environment.chomp
  	ename_clean = environment;
	ename_clean = ename_clean.gsub /\-ATS/, ''
	return ename_clean
end
####################################################################
####################################################################
#  This definition is where you add new statistics for _stats page
####################################################################
####################################################################
def create_stats_in_db(environment, servername, sname_clean)
    db = Mysql.new 'localhost', 'newrelic', 'newrelic', 'newrelic_ats'
    #puts "#{servername} - #{sname_clean} - #{environment}"
	current_connection = "origin_server-current_connections_count-#{sname_clean}"
	#pp current_connection
	db.query ("INSERT INTO #{environment} VALUES ('#{current_connection}','0','#{servername}','proxy.node.http.origin_server_current_connections_count','current_connections_count')")
	xacts_per_second = "node-user_agent_xacts_per_second-#{sname_clean}"
	db.query ("INSERT INTO #{environment} VALUES ('#{xacts_per_second}','0','#{servername}','proxy.node.user_agent_xacts_per_second','xacts_per_second')")
	cluster_connections_open = "process-cluster-connections_open-#{sname_clean}"
	db.query ("INSERT INTO #{environment} VALUES ('#{cluster_connections_open}','0','#{servername}','proxy.process.cluster.connections_open','connections_open')")
	cache_hit_ratio_avg_10s_int_pct = "node-cache_hit_ratio_avg_10s_int_pct-#{sname_clean}"
	db.query ("INSERT INTO #{environment} VALUES ('#{cache_hit_ratio_avg_10s_int_pct}','0','#{servername}','proxy.node.cache_hit_ratio_avg_10s_int_pct','cache_hit_ratio')")
	cache_hit_mem_ratio_avg_10s_int_pct = "node-cache_hit_mem_ratio_avg_10s_int_pct-#{sname_clean}"
	db.query ("INSERT INTO #{environment} VALUES ('#{cache_hit_mem_ratio_avg_10s_int_pct}','0','#{servername}','proxy.node.cache_hit_mem_ratio_avg_10s_int_pct','cache_hit_mem')")
    current_cache_connections = "ATS-proxy_node_current_proxy_connections-#{sname_clean}"
    db.query ("INSERT INTO #{environment} VALUES('#{current_cache_connections}','0','#{servername}','proxy.node.current_cache_connections','current_cache_connections')")
    current_server_connections = "ATS-proxy_node_current_server_connections-#{sname_clean}"
    db.query ("INSERT INTO #{environment} VALUES('#{current_server_connections}','0','#{servername}','proxy.node.current_server_connections','current_server_connections')")
    contract_from_memory_60s_rate = "ATS-contract_from_memory_60s_rate-#{sname_clean}"
  	db.close
end

#Initialize Database
init_db

#Get Node information from Chef
get_nodes

#Begin building stat value holder
$environment_list.each do |env|
	db = Mysql.new 'localhost', 'newrelic', 'newrelic', 'newrelic_ats'
	dbresult = db.query("SELECT * FROM ats WHERE environment LIKE '%#{env}%' order by environment")
	dbresult.each do |servername,environment|
		#puts "#{environment} - #{servername}"
		sname_clean = clean_server_name_for_db(servername)
		ename_clean = clean_env_name_for_db(env)
		create_stats_in_db(ename_clean,servername,sname_clean)
	end
end


#Create Agent Scripts
$environment_list.each do |env|
	env.capitalize
	ename_clean = clean_env_name_for_db(env)
	db = Mysql.new 'localhost', 'newrelic', 'newrelic', 'newrelic_ats'
	open('agent-'+env+'.rb', 'w') { |f|
  		f.puts 'require "mysql"'
  		f.puts 'require "rest-client"'
  		f.puts 'require "json"'
  		f.puts 'require "newrelic_plugin"'

		f.puts 'module ATSAgent'
		f.puts '  class Agent < NewRelic::Plugin::Agent::Base'
		f.puts '    agent_guid "com.myapp.srv.ats"'
		f.puts '    agent_version "3.0"'
		f.puts '    agent_human_labels("ATSV1") {\''+ename_clean+'\'}'
		f.puts '    def get_metrics'
		f.puts '      db = Mysql.new \'localhost\',\'newrelic\',\'newrelic\',\'newrelic_ats\''
		f.puts '      srvlist = db.query("SELECT servername FROM ats WHERE environment LIKE \'%'+env+'%\' and enabled = true")'
		f.puts '      srvlist.each do |srv|'
		f.puts '        begin'
		f.puts '          response = RestClient.get("http://#{srv[0]}:8080/_stats")'
		f.puts '        rescue Errno::ECONNREFUSED'
		f.puts '          false'
		f.puts '        end'
		f.puts ''
		f.puts '        begin'
		f.puts '          json = JSON.parse(response)'
		f.puts '          json[\'global\'].each do |stat|'
		f.puts '            #puts stat'
		f.puts '          end'
		f.puts ''
		data = db.query("SELECT DISTINCT ats_stat, variable FROM #{env}")
		data.each do |stat,var|
			f.puts '          '+var+' = json[\'global\'][\''+stat+'\'].to_i'
		end
		f.puts ''
		data = db.query("SELECT DISTINCT variable FROM #{env}")
		data.each do |name|
			var = name[0]
			f.puts '          db.query "UPDATE '+env+' SET value = \'#{'+var+'}\' WHERE servername LIKE \'%#{srv[0]}%\' AND hash LIKE \'%'+var+'%\'"'
		end
		f.puts ''
		f.puts '        rescue'
		f.puts ''
		f.puts '        end'
		f.puts '      end'
		f.puts '      db.close'
		f.puts '    end'
		f.puts ''
		f.puts '    def poll_cycle'
		f.puts ''
		f.puts '      get_metrics'
		f.puts ''
		f.puts '      db = Mysql.new \'localhost\',\'newrelic\',\'newrelic\',\'newrelic_ats\''
		f.puts ''
		f.puts '      nrmetric = db.query("SELECT hash, value FROM '+env+'")'
		f.puts '      nrmetric.each do |nr|'
		f.puts '        report_metric "#{nr[0]}", "points", "#{nr[1]}"'
		f.puts '      end'
		f.puts ''
		f.puts '    db.close'
		f.puts '    end'
		f.puts '  end'
		f.puts '  NewRelic::Plugin::Setup.install_agent :atsv2, ATSAgent'
		f.puts '  NewRelic::Plugin::Run.setup_and_run'
		f.puts 'end'
	}
	open('Procfile','a'){ |f|
		f.puts ''+env+': ruby agent-'+env+'.rb'
	}
end
