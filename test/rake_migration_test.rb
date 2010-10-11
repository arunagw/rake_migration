require File.dirname(__FILE__) + '/test_helper'

TEST_ROOT       = File.expand_path(File.dirname(__FILE__))
RAKE_MIGRATIONS_ROOT = TEST_ROOT + "/../rake/migrate/"
require File.dirname(__FILE__) + '/../models/blog'

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
  
  class RakeMigrationTest < ActiveSupport::TestCase

    def setup
      ActiveRecord::RakeMigration.verbose = true
      ActiveRecord::RakeMigration.message_count = 0
      Blog.connection.drop_table('blogs') if Blog.connection.table_exists?(:blogs)
      Blog.connection.create_table :blogs do |t|
        t.column :text, :text
        t.timestamps
      end
    end

    def test_migrate
      rake_migration = ActiveRecord::RakeMigration.new(:filename => './rake/migrate/20101008114735_task_01.rb',
                                          :version => '20101008114735')
      rake_migration.migrate
      assert_equal 1, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

  end


  class RakeMigrationProxyTest < ActiveSupport::TestCase

    def setup
      Blog.connection.drop_table('blogs') if Blog.connection.table_exists?(:blogs)
      Blog.connection.create_table :blogs do |t|
        t.column :text, :text
        t.timestamps
      end
    end

    def test_migrate
      rake_migration = ActiveRecord::RakeMigrationProxy.new
      rake_migration.name = 'Task01'
      rake_migration.filename = './rake/migrate/20101008114735_task_01.rb'
      rake_migration.version = '20101008114735'
      rake_migration.migrate
      assert_equal 1, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

  end


  class RakeMigratorTest < ActiveSupport::TestCase

    def setup
      Blog.connection.drop_table('blogs') if Blog.connection.table_exists?(:blogs)
      Blog.connection.create_table :blogs do |t|
        t.column :text, :text
        t.timestamps
      end
    end

    def test_run
      ActiveRecord::RakeMigrator.run(RAKE_MIGRATIONS_ROOT,20101008114735)
      assert_equal 1, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

    def test_migrate
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      assert_equal 3, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

  end


end

