require "bundler/gem_tasks"
require "rake/testtask"

task :default

has_gui = begin
    require "Qt"
    true
rescue LoadError
    false
end

Rake::TestTask.new("test:lib") do |t|
    t.libs << "lib"
    t.libs << "."

    t.test_files = FileList["test/**/test_*.rb"]
    t.test_files.exclude("test/gui/**/test_*.rb") unless has_gui
end
task "test" => "test:lib"

task "rubocop" do
    raise "rubocop failed" unless system(ENV["RUBOCOP_CMD"] || "rubocop")
end

task "test" => "rubocop" if ENV["RUBOCOP"] != "0"

task gem: :build
