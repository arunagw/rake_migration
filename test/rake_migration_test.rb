require File.dirname(__FILE__) + '/test_helper'

TEST_ROOT       = File.expand_path(File.dirname(__FILE__))
RAKE_MIGRATIONS_ROOT = TEST_ROOT + "/../rake/migrate/"
require File.dirname(__FILE__) + '/../models/blog'

#If DB Migrations works then rake_migration will also work.
if ActiveRecord::Base.connection.supports_migrations?
  ActiveRecord::Base.connection.initialize_schema_rake_migrations_table
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
      ActiveRecord::RakeMigration.verbose = false
      ActiveRecord::RakeMigration.message_count = 0
      Blog.connection.drop_table('blogs') if Blog.connection.table_exists?(:blogs)
      Blog.connection.create_table :blogs do |t|
        t.column :text, :text
        t.timestamps
      end
    end

    def test_migrate
      rake_migration = ActiveRecord::RakeMigration.new(
              :filename => './rake/migrate/20101008114735_task_01.rb',
              :version => '20101008114735')
      rake_migration.migrate
      assert_equal 1, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

  end


  class RakeMigrationProxyTest < ActiveSupport::TestCase

    def setup
      ActiveRecord::RakeMigration.verbose = false
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
      ActiveRecord::RakeMigration.verbose = false
      Blog.connection.drop_table('blogs') if Blog.connection.table_exists?(:blogs)
      Blog.connection.create_table :blogs do |t|
        t.column :text, :text
        t.timestamps
      end
      Blog.connection.execute('DELETE FROM blogs')
      Blog.connection.execute('DELETE FROM rake_migrations')
    end

    def test_self_run
      ActiveRecord::RakeMigrator.run(RAKE_MIGRATIONS_ROOT,20101008114735)
      assert_equal 1, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

    def test_self_migrate
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      assert_equal 3, Blog.count
      assert_equal 'My first file to update system', Blog.first.text
    end

    def test_self_schema_migration_table_name
      assert_equal ActiveRecord::RakeMigrator.schema_rake_migrations_table_name, 'rake_migrations'
    end

    def test_self_get_all_versions
      assert_equal ActiveRecord::RakeMigrator.get_all_versions, []
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      assert_equal ActiveRecord::RakeMigrator.get_all_versions.size, 3
    end

    def test_self_current_version
      assert_equal ActiveRecord::RakeMigrator.current_version, 0
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      assert_equal ActiveRecord::RakeMigrator.current_version, 20101008130439
    end

    def test_self_proper_table_name
      assert_equal ActiveRecord::RakeMigrator.proper_table_name('rake_migrations'),'rake_migrations'
      assert_not_equal ActiveRecord::RakeMigrator.proper_table_name('rake_migrations'),'table_name'
    end

    def test_initialize
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114735)
      assert_equal rake_migrator.instance_variable_get('@target_version'), 20101008114735
      assert_equal rake_migrator.instance_variable_get('@rake_migrations_path'), RAKE_MIGRATIONS_ROOT
    end

    def test_current_version_without_run
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,000)
      assert_equal rake_migrator.current_version, 0
    end

    def test_current_version
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,000)
      assert_equal rake_migrator.current_version, 20101008130439
    end

    def test_current_migration_without_run
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,000)
      assert_equal rake_migrator.current_migration, nil
    end

    def test_current_migration
      ActiveRecord::RakeMigrator.migrate(RAKE_MIGRATIONS_ROOT)
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,000)
      assert_equal rake_migrator.current_migration.version, 20101008130439
    end

    def test_run
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114813)
      rake_migrator.run
      assert_equal rake_migrator.current_version, 20101008114813
    end

    def test_migrate
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114813)
      rake_migrator.migrate
      assert ActiveRecord::RakeMigrator.get_all_versions.include?(20101008114813)
      assert ActiveRecord::RakeMigrator.get_all_versions.include?(20101008114735)
    end

    def test_rake_migrations
      rake_migrator = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114813)
      assert_equal rake_migrator.rake_migrations.size,3
      assert rake_migrator.rake_migrations.map(&:version).include?(20101008114813)
    end

    def test_pending_rake_migrations
      rake_migrator01 = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114813)
      rake_migrator01.migrate
      rake_migrator02 = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008130439)
      assert rake_migrator02.pending_rake_migrations.map(&:version).include?(20101008130439)
    end

    def test_migrated
      rake_migrator01 = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,20101008114813)
      rake_migrator01.migrate
      rake_migrator02 = ActiveRecord::RakeMigrator.new(RAKE_MIGRATIONS_ROOT,0000)
      assert rake_migrator02.migrated.include?(20101008114813)
      assert rake_migrator02.migrated.include?(20101008114735)
    end

  end


end

