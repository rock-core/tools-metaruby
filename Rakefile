require "bundler/gem_tasks"
require "rake/testtask"

task :default

has_gui = begin
              require 'Qt'
              true
          rescue LoadError
              false
          end

Rake::TestTask.new(:test) do |t|
    t.libs << "lib"
    t.libs << "."

    file_list = FileList['test/**/test_*.rb']
    if !has_gui
        file_list.exclude('test/gui/**/test_*.rb')
    end
end

task :gem => :build
