module ActiveRecord

  class DuplicateRakeMigrationVersionError < ActiveRecordError#:nodoc:
    def initialize(version)
      super("Multiple rake migrations have the version number #{version}")
    end
  end

  class DuplicateRakeMigrationNameError < ActiveRecordError#:nodoc:
    def initialize(name)
      super("Multiple rake migrations have the name #{name}")
    end
  end

  class UnknownRakeMigrationVersionError < ActiveRecordError #:nodoc:
    def initialize(version)
      super("No rake migration with version number #{version}")
    end
  end

  class IllegalRakeMigrationNameError < ActiveRecordError#:nodoc:
    def initialize(name)
      super("Illegal name for rake migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed)")
    end
  end

  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      def initialize_schema_rake_migrations_table
        sm_table = ActiveRecord::RakeMigrator.schema_rake_migrations_table_name

        unless tables.detect { |t| t == sm_table }
          create_table(sm_table, :id => false) do |schema_migrations_table|
            schema_migrations_table.column :version, :string, :null => false
          end
          add_index sm_table, :version, :unique => true,
                    :name => "#{Base.table_name_prefix}unique_schema_migrations#{Base.table_name_suffix}"
        end
      end
    end
  end

  class RakeMigration
    @@verbose = true
    cattr_accessor :verbose
    attr_accessor :filename, :version

    def initialize(opts)
      @filename = opts[:filename]
      @version = opts[:version]
    end

    # Execute this rake migration in the named direction
    def migrate
      announce "migrating"
      result = nil
      time = Benchmark.measure { result = load("#{filename}") }
      announce "migrated (%.4fs)" % time.real; write
      result
    end

    def write(text="")
      puts(text) if @@verbose
    end

    def announce(message)
      text = "#{version} #{filename}: #{message}"
      length = [0, 75 - text.length].max
      write "== %s %s" % [text, "=" * length]
    end

  end

  # RakeMigrationProxy is used to defer loading of the actual migration classes
  # until they are needed
  class RakeMigrationProxy

    attr_accessor :name, :version, :filename

    delegate :migrate, :announce, :write, :to => :migration

    def migrate
      migration.migrate
    end

    private

    def migration
      @migration ||= load_migration
    end

    def load_migration
      RakeMigration.new(:filename => filename, :version => version)
    end

  end

  class RakeMigrator#:nodoc:
    class << self
      def migrate(rake_migrations_path, target_version = nil)
        self.new(rake_migrations_path, target_version).migrate
      end

      def run(rake_migrations_path, target_version)
        self.new(rake_migrations_path, target_version).run
      end

      def schema_rake_migrations_table_name
        Base.table_name_prefix + 'rake_migrations' + Base.table_name_suffix
      end

      def get_all_versions
        Base.connection.select_values("SELECT version FROM #{schema_rake_migrations_table_name}").map(&:to_i).sort
      end

      def current_version
        sm_table = schema_rake_migrations_table_name
        if Base.connection.table_exists?(sm_table)
          get_all_versions.max || 0
        else
          0
        end
      end

      def proper_table_name(name)
        # Use the Active Record objects own table_name, or pre/suffix from ActiveRecord::Base if name is a symbol/string
        name.table_name rescue "#{ActiveRecord::Base.table_name_prefix}#{name}#{ActiveRecord::Base.table_name_suffix}"
      end
    end

    def initialize(rake_migrations_path, target_version = nil)
      raise StandardError.new("This database does not yet support rake_migrations") unless Base.connection.supports_migrations?
      Base.connection.initialize_schema_rake_migrations_table
      @rake_migrations_path, @target_version = rake_migrations_path, target_version
    end

    def current_version
      migrated.last || 0
    end

    def current_migration
      rake_migrations.detect { |m| m.version == current_version }
    end

    def run
      target = rake_migrations.detect { |m| m.version == @target_version }
      raise UnknownRakeMigrationVersionError.new(@target_version) if target.nil?
      unless (migrated.include?(target.version.to_i))
        target.migrate
        record_version_state_after_migrating(target.version)
      end
    end

    def migrate
      current = rake_migrations.detect { |m| m.version == current_version }
      target = rake_migrations.detect { |m| m.version == @target_version }

      if target.nil? && !@target_version.nil? && @target_version > 0
        raise UnknownRakeMigrationVersionError.new(@target_version)
      end

      start = rake_migrations.index(current) || 0
      finish = rake_migrations.index(target) || rake_migrations.size - 1
      runnable = rake_migrations[start..finish]

      runnable.each do |migration|
        Base.logger.info "Migrating to #{migration.name} (#{migration.version})"
        # On our way up, we skip migrating the ones we've already migrated
        next if migrated.include?(migration.version.to_i)

        begin
          ddl_transaction do
            migration.migrate
            record_version_state_after_migrating(migration.version)
          end
        rescue => e
          canceled_msg = Base.connection.supports_ddl_transactions? ? "this and " : ""
          raise StandardError, "An error has occurred, #{canceled_msg}all later rake rake_migrations canceled:\n\n#{e}", e.backtrace
        end
      end
    end

    def rake_migrations
      @rake_migrations ||= begin
        files = Dir["#{@rake_migrations_path}/[0-9]*_*.rb"]

        rake_migrations = files.inject([]) do |klasses, file|
          version, name = file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first

          raise IllegalRakeMigrationNameError.new(file) unless version
          version = version.to_i

          if klasses.detect { |m| m.version == version }
            raise DuplicateRakeMigrationVersionError.new(version)
          end

          if klasses.detect { |m| m.name == name.camelize }
            raise DuplicateRakeMigrationNameError.new(name.camelize)
          end

          klasses << returning(RakeMigrationProxy.new) do |migration|
            migration.name     = name
            migration.version  = version
            migration.filename = file
          end
        end

        rake_migrations = rake_migrations.sort_by(&:version)
        rake_migrations
      end
    end

    def pending_rake_migrations
      already_migrated = migrated
      rake_migrations.reject { |m| already_migrated.include?(m.version.to_i) }
    end

    def migrated
      @migrated_versions ||= self.class.get_all_versions
    end

    private
    def record_version_state_after_migrating(version)
      sm_table = self.class.schema_rake_migrations_table_name
      @migrated_versions ||= []
      @migrated_versions.push(version.to_i).sort!
      Base.connection.insert("INSERT INTO #{sm_table} (version) VALUES ('#{version}')")
    end

    # Wrap the migration in a transaction only if supported by the adapter.
    def ddl_transaction(&block)
      if Base.connection.supports_ddl_transactions?
        Base.transaction { block.call }
      else
        block.call
      end
    end
  end
end
