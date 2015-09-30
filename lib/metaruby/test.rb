# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] == '1'
    begin
        require 'simplecov'
        SimpleCov.start do
            add_filter "test"
        end
    rescue LoadError
        require 'metaruby'
        MetaRuby.warn "coverage is disabled because the 'simplecov' gem cannot be loaded"
    rescue Exception => e
        require 'metaruby'
        MetaRuby.warn "coverage is disabled: #{e.message}"
    end
end

require 'metaruby'
require 'minitest/autorun'
require 'minitest/spec'
require 'flexmock/minitest'

if ENV['TEST_ENABLE_PRY'] != '0'
    begin
        require 'pry'
        if ENV['TEST_DEBUG'] == '1'
            require 'pry-rescue/minitest'
        end
    rescue Exception
        MetaRuby.warn "debugging is disabled because the 'pry' gem cannot be loaded"
    end
end

module MetaRuby
    # This module is the common setup for all tests
    #
    # It should be included in the toplevel describe blocks
    #
    # @example
    #   require 'metaruby/test'
    #   describe MetaRuby do
    #     include MetaRuby::SelfTest
    #   end
    #
    module SelfTest
        def setup
            # Setup code for all the tests
        end

        def teardown
        end
    end
end

module Minitest
    class Spec
        include MetaRuby::SelfTest
    end
    class Test
        include MetaRuby::SelfTest
    end
end

