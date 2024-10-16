require "metaruby/dsls/doc"
require "metaruby/dsls/find_through_method_missing"

module MetaRuby
    # DSLs-related tools
    #
    # == Find through method missing
    #
    # The find through method missing functionality is meant to allow classes to
    # turn objects that can be found (with a method that finds an object by its
    # name) into an attribute call as e.g.
    #
    #   task.test_event # => task.find_event("test")
    #
    # See {DSLs::FindThroughMethodMissing} for a complete description
    #
    # == Documentation parsing
    #
    # This provides the logic to find a documentation block above a DSL-like
    # object creation. For instance, given a class that looks like
    #
    #   class Task
    #     def event(name) # creates an event object with the given name
    #     end
    #   end
    #
    # Used in a DSL context like so:
    #
    #   # The test event allows us
    #   #
    #   # To provide an example
    #   event 'test'
    #
    # The parse_documentation method allows to extract the comment block above
    # the 'event' call. See {DSLs.parse_documentation} for more information
    module DSLs
    end
end
