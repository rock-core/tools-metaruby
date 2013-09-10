# Coverage is enabled by default when running the whole suite
ENV['TEST_ENABLE_COVERAGE'] ||= '1'

# Require all your test files here. Always prepend ./ and use the relative path
# to the Ruby library root
require 'metaruby/test'
require './test/test_class'
require './test/test_module'
require './test/test_attributes'
require './test/test_registration'
require './test/test_dsls'

# Put the root logger to DEBUG so that all debug blocks are executed
MetaRuby.logger = Logger.new(File.open("/dev/null", 'w'))
MetaRuby.logger.level = Logger::DEBUG
