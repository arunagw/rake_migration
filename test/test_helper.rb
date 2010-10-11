require 'rubygems'
gem 'activesupport', '~> 2.3.4'
gem 'activerecord', '~> 2.3.4'
gem 'rails', '~> 2.3.4'

require "active_record"
require "active_support"
require 'active_support/test_case'
require 'yaml'

ENV['RAILS_ENV'] = 'test'
require File.dirname(__FILE__) + '/../../../../config/environment.rb'

ActiveRecord::Base.configurations = {
  'db1' => {
  :adapter  => 'mysql',
  :username => 'root',
  :encoding => 'utf8',
  :database => 'rake_migration_test1',
},
'db2' => {
  :adapter  => 'mysql',
  :username => 'root',
  :database => 'rake_migration_test2'
}
}

ActiveRecord::Base.establish_connection('db1')
