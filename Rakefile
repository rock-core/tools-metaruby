require "bundler/gem_tasks"
require "rake/testtask"

task :default

Rake::TestTask.new(:test) do |t|
    t.libs << "lib"
    t.libs << "."
    t.test_files = FileList['test/suite.rb']
end

task :gem => :build
