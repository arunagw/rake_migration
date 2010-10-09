require File.dirname(__FILE__) + '/test_helper'

TEST_ROOT       = File.expand_path(File.dirname(__FILE__))
RAKE_MIGRATIONS_ROOT = TEST_ROOT + "/rake_migrations"

dbconfig = YAML.load(File.read("./../../../config/database.yml"))[RAILS_ENV]

ActiveRecord::Base.establish_connection(dbconfig)


#If DB Migrations works then rake_migration will also work.
if ActiveRecord::Base.connection.supports_migrations?
  class BigNumber < ActiveRecord::Base; end

  class Reminder < ActiveRecord::Base; end

  class ActiveRecord::RakeMigration
    class <<self
      attr_accessor :message_count
      def puts(text="")
        self.message_count ||= 0
        self.message_count += 1
      end
    end
  end

  class RakeMigrationTest < Test::Unit::TestCase

    def setup
      ActiveRecord::RakeMigration.verbose = true
      ActiveRecord::RakeMigration.message_count = 0
    end

    def test_hello
      assert true 
    end

  end

end

