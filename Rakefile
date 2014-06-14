task 'default'
package_name = 'metaruby'

require 'utilrb/doc/rake'
Utilrb.doc :include => ['lib/**/*.rb']

begin
    require 'hoe'
    Hoe::plugin :yard

    config = Hoe.spec package_name do
        self.developer "Sylvain Joyeux", "sylvain.joyeux@dfki.de"
        self.summary = 'Modelling using the Ruby language as a metamodel'
        self.description = paragraphs_of('README.markdown', 3..6).join("\n\n")
        self.changes     = paragraphs_of('History.txt', 0..1).join("\n\n")
        self.readme_file = 'README.markdown'
        self.history_file = 'History.txt'
        self.license 'LGPLv3+'

        extra_deps <<
            ['utilrb',   '>= 1.3.4'] <<
            ['rake',     '>= 0.8'] <<
            ['hoe-yard', '>= 0.1.2'] <<
            ['pry', '>= 0.9.12']
    end

    Rake.clear_tasks(/^default$/)
    task :default => []
    task :doc => :yard
rescue LoadError
    STDERR.puts "cannot load the Hoe gem. Distribution is disabled"
rescue Exception => e
    puts e.backtrace
    if e.message !~ /\.rubyforge/
        STDERR.puts "WARN: cannot load the Hoe gem, or Hoe fails. Publishing tasks are disabled"
        STDERR.puts "WARN: error message is: #{e.message}"
    end
end
