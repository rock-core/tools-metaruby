require "bundler/gem_tasks"
require "rake/testtask"

task :default

has_gui = begin
    require "Qt"
    true
rescue LoadError
    false
end

Rake::TestTask.new(:test) do |t|
    t.libs << "lib"
    t.libs << "."

    file_list = FileList["test/**/test_*.rb"]
    file_list.exclude("test/gui/**/test_*.rb") unless has_gui
end

task "rubocop" do
    raise "rubocop failed" unless system(ENV["RUBOCOP_CMD"] || "rubocop")
end
task "test" => "rubocop" if ENV["RUBOCOP"] != "0"

task gem: :build
