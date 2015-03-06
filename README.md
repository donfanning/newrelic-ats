ATS for New Relic
----------------------

Requirements:
- MySQL (to be used as a value store)
- Ruby >=2.0
- RubyGems
- A chef pem key and user
- foreman gem (ruby)


This is the code for pushing Apache Traffic Server statistics into New Relic for reporting.  This is a Ruby based plugin that relies on a MySQL backend to utilized as a temporary value store.

There are a number of .txt files:  These are the server buckets in which the server FQDN goes in and it will be attributed to a specific environment (Prod/Stage/etc.) so that the metrics can be grouped together.

Once the .txt file is updated, use the nrcreate.rb script which reads the files and generates value stores in MySQL to which will be utilized in the rest of the code.

From there, each ruby agent script should be launched individually (agent-prod/agent-perf/etc.) or via foreman as described below.

We currently use foreman to launch the scripts in parallel. A Procfile is created with the nrcreate.rb script.  If the init.d needs to be updated you can run the following command to get the init.d script updated:

```foreman export initscript /etc/init.d -a ats -u root -l /var/log/atsstats.log```

This will produce an init.d script.  However it will spit out some warnings when you use it. To mute it, add these lines.
```
# Define LSB log_* functions.
# To be replaced by LSB functions
# Defined here for distributions that don't define
# log_daemon_msg
log_daemon_msg () {
    echo $@
}

# To be replaced by LSB functions
# Defined here for distributions that don't define
# log_end_msg
log_end_msg () {
    retval=$1
    if [ $retval -eq 0 ]; then
        echo "."
    else
        echo " failed!"
    fi
    return $retval
}
```


Start out by installing:

1. yum install mysql, mysql-client, gcc (with kernel headers so changing yum.conf to allow kernel installs) 
2. install ruby gems from the internet 
3. do a gem install of "mysql", "rest-client", "json", "newrelic_plugin", "foreman", "foreman-export-initscript" 
4. run mysql as root 
5. use mysql; CREATE USER 'newrelic'@'localhost' IDENTIFIED BY ‘’; create database newrelic_ats; grant all privileges on newrelic_ats.* to ‘newrelic’@‘localhost; flush privileges;
6. exit DB and then vi config/newrelic_plugin.yml > comment out proxy if necessary 
7. you will need to have your chef pem file on the machine so the script can build the hostnames from chef automatically. 
8. run nrcreate.rb and it will create all necessary agent scripts per environment. 
9. the foreman gem acts to start up all the subagents listed in Procfile. So just run foreman start.

If you want to add an environment, update the nrcreate script's array near the top. You then need to re-run the nrcreate script, kill the current pids via foreman stop or via a screen session currently, and then run start again. 


There is an additional script called enable_server.rb which is to enable/disable nodes out of the MySQL server for which it uses as a temporary value store.  This is used if you need to disable a node but not delete it.
The script will try and recover from any bad server but sometimes it will not failover hence being able to disable the bad server from the list.


