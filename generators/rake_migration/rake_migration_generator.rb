class RakeMigrationGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.migration_template 'empty_rake_file.rb', 'rake/migrate'
    end
  end
end
