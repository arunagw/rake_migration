require 'rails/generators/active_record'
class RakeMigrationGenerator < ActiveRecord::Generators::Base
  source_root File.expand_path("../templates", __FILE__)
  def mainfest
    migration_template 'empty_rake_file.rb', "rake/migrate/#{file_name}.rb"
  end  
end
