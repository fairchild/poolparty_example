$:.unshift '/Users/mfairchild/Code/poolparty/lib/'
require "poolparty"

pool :party do
  instances 2..3

  cloud :app do
    keypair "#{cloud_name}" #modify this to point to your EC2 key file, one key per cloud
                            # ~/.ssh and ~/.ec2/ are searched by default
                            # the cloud_name method is being used here, which will return the current cloud name
                            # This will work as long as you follow the convention of key_name == cloud_name
                            
    # the first available will be selected for each node, first come first served
    elastic_ips ['75.101.145.49'] #, '75.101.141.103']  
    
    enable :git, :apache
    # enable :haproxy # Also sets up Apache2
                          
    has_gem_package "rails", :version => "2.3.2"  #must match version specified in the rails environment.rb
    has_package "mysql-client"
    has_package "mysql-server"
    has_package "libmysqlclient15-dev"    #so we can install the mysql gem
    has_gem_package "mysql"               #so rails can talk to mysql
    has_service "mysql"                   #run the mysql server

    has_package 'vim'
    has_package 'irb'

    has_file "/etc/motd", :content => "Welcome to your poolparty #{cloud_name} instance!"
    
    #FIXME:
    #has_rails_deploy is currently (1.2) broken if we're using mysql. the problem is that the migration fails because
    # the db hasn't been created yet. a worksaround could have been to use:
    #   migration_command "rake db:create && RAILS_ENV=production rake db:migrate"
    # but rails_deploy doesn't currently pass on the migration_command to chef_deploy, so for the time being, 
    # we create the db manually
    
    apache do
      listen 80
      has_file :name => "/var/www/index.html" do
        content "<h1>Welcome to your new poolparty instance</h1><hr><h3>cloud: #{self.cloud.name}</h3> "
        mode 0644
        owner "www-data"
      end
      
      # has_virtualhost do
      #   name 'poolparty.metavirt.com'
      #   has_deploy_directory('bob', 
      #                      :from => "~/Sites/poolparty-website", 
      #                      :to => '/var/www/poolparty.metavirt.com',
      #                      :owner => 'www-data',
      #                      :git_pull_first => true  #do a git pull in the from directory before syncing
      #   )
      #   # has_git_repo 'site' do
      #   #   source 'git://github.com/fairchild/poolparty-website.git'
      #   #   at '/var/www/poolparty.metavirt.com'
      #   # end
      # end
      
      install_passenger
      has_passengersite :with_deployment_directories => true do
        name "ci.metavirt.com"
        has_exec(:name => "Create mysql db", :command => "mysql -e 'create database if not exists ci_metavirt;'")
        
        has_rails_deploy "ci.metavirt.com" do
          dir "/var/www"
          migration_command "rake db:schema:load"
          repo "git://github.com/auser/paparazzi.git"
          user "www-data"
          install_sqlite
          # Can also be a relative file path to the database.yml
          database_yml '
production:
  adapter: mysql
  database: ci_metavirt
  host: localhost
  user: root
  password:
'
        end
      end
      

      
    end
    

    # # Use chef to deploy our rails app using apache + mod_rails/passenger  
    # has_rails_deploy "my_app" do           
    #   dir "/var/www"                                              
    #   repo "git://github.com/emiltin/poolparty_example.git"       #download rails app from this repo
    #   user "www-data"                                             
    #   database_yml "#{File.dirname(__FILE__)}/../database.yml"    #will copy it to the shared folder
    # end                                                           
    #                                                               
    # chef do                                                       
    #   include_recipes "#{File.dirname(__FILE__)}/../cookbooks/*"   #will be uploaded to instances, but not run
    #   templates "#{File.dirname(__FILE__)}/templates/"             #will be uploaded to instances
    #   # recipe "#{File.dirname(__FILE__)}/chef.rb"                   #will be uploaded to instances, and run 
    # end
    
    verify do
      ping 80
    end
    
    
  end

end
