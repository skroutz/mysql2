require "rake/extensiontask"

def gemspec
  @clean_gemspec ||= eval(File.read(File.expand_path('../../mysql2.gemspec', __FILE__)))
end

Rake::ExtensionTask.new("mysql2", gemspec) do |ext|
  # put binaries into lib/mysql2/ or lib/mysql2/x.y/
  ext.lib_dir = File.join 'lib', 'mysql2'

  # clean compiled extension
  CLEAN.include "#{ext.lib_dir}/*.#{RbConfig::CONFIG['DLEXT']}"

  if RUBY_PLATFORM =~ /mswin|mingw/ then
    # Expand the path because the build dir is 3-4 levels deep in tmp/platform/version/
    connector_dir = File.expand_path("../../vendor/#{vendor_mysql_dir}", __FILE__)
    ext.config_options = [ "--with-mysql-dir=#{connector_dir}" ]
  else
    ext.cross_compile = true
    ext.cross_platform = ['x86-mingw32', 'x86-mswin32-60', 'x64-mingw32']
    ext.cross_config_options << {
      'x86-mingw32'    => "--with-mysql-dir=" + File.expand_path("../../vendor/#{vendor_mysql_dir('x86')}", __FILE__),
      'x86-mswin32-60' => "--with-mysql-dir=" + File.expand_path("../../vendor/#{vendor_mysql_dir('x86')}", __FILE__),
      'x64-mingw32'    => "--with-mysql-dir=" + File.expand_path("../../vendor/#{vendor_mysql_dir('x64')}", __FILE__),
    }

    ext.cross_compiling do |spec|
      Rake::Task['lib/mysql2/mysql2.rb'].invoke
      # vendor/libmysql.dll is invoked from extconf.rb
      Rake::Task['vendor/README'].invoke
      spec.files << 'lib/mysql2/mysql2.rb'
      spec.files << 'vendor/libmysql.dll'
      spec.files << 'vendor/README'
      spec.post_install_message = <<-POST_INSTALL_MESSAGE

======================================================================================================

  You've installed the binary version of #{spec.name}.
  It was built using MySQL Connector/C version #{CONNECTOR_VERSION}.
  It's recommended to use the exact same version to avoid potential issues.

  At the time of building this gem, the necessary DLL files were retrieved from:
  #{vendor_mysql_url(spec.platform)}

  This gem *includes* vendor/libmysql.dll with redistribution notice in vendor/README.

======================================================================================================

      POST_INSTALL_MESSAGE
    end
  end
end
Rake::Task[:spec].prerequisites << :compile

file 'vendor/README' do |t|
  connector_dir = File.expand_path("../../vendor/#{vendor_mysql_dir}", __FILE__)
  when_writing 'copying Connector/C README' do
    cp "#{connector_dir}/README", 'vendor/README'
  end
end

file 'lib/mysql2/mysql2.rb' do |t|
  name = gemspec.name
  File.open(t.name, 'wb') do |f|
    f.write <<-eoruby
RUBY_VERSION =~ /(\\d+.\\d+)/
require "#{name}/\#{$1}/#{name}"
    eoruby
  end
end

# DevKit task following the example of Luis Lavena's test-ruby-c-extension
task :devkit do
  begin
    require "devkit"
  rescue LoadError => e
    abort "Failed to activate RubyInstaller's DevKit required for compilation."
  end
end

if RUBY_PLATFORM =~ /mingw|mswin/ then
  Rake::Task['compile'].prerequisites.unshift 'vendor:mysql'
  Rake::Task['compile'].prerequisites.unshift 'devkit'
else
  if Rake::Task.tasks.map {|t| t.name }.include? 'cross'
    Rake::Task['cross'].prerequisites.unshift 'vendor:mysql:cross'
  end
end
