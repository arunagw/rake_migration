namespace :rake_migration do
  task :load_config => :rails_env do
    require 'active_record'
    ActiveRecord::Base.configurations = Rails::Configuration.new.database_configuration
  end

  desc "Migrate the tasks through scripts in rake/migrate. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => :environment do
    ActiveRecord::RakeMigration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ActiveRecord::RakeMigrator.migrate("rake/migrate", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  namespace :migrate do
    desc 'Runs the given rake migration VERSION.'
    task :run => :environment do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      ActiveRecord::RakeMigrator.run("rake/migrate", version)
    end

  end

  desc "Retrieves the current schema version number"
  task :version => :environment do
    puts "Current version: #{ActiveRecord::RakeMigrator.current_version}"
  end


end

