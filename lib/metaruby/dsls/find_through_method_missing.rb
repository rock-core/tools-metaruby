require 'metaruby/attributes'

module MetaRuby
    module DSLs
        # Common definition of #respond_to_missing? and #method_missing to be
        # used in conjunction with {DSLs.find_through_method_missing} and
        # {DSLs.has_through_method_missing?}
        #
        # @example resolve 'event' objects using method_missing
        #   class Task
        #      # Tests if this task has an event by this name
        #      #
        #      # @param [String] name
        #      # @return [Boolean]
        #      def has_event?(name)
        #      end
        #
        #      # Finds an event by name
        #      #
        #      # @param [String] name
        #      # @return [Object,nil] the found event, or nil if there is no
        #      #   event by this name
        #      def find_event(name)
        #      end
        #
        #      include MetaRuby::DSLs::FindThroughMethodMissing
        #
        #      # Check if the given method matches a find object
        #      def has_through_method_missing?(m)
        #        MetaRuby::DSLs.has_through_method_missing?(
        #           self, m, '_event' => :has_event?) || super
        #      end
        #
        #      # Check if the given method matches a find object
        #      def find_through_method_missing(m, args)
        #        MetaRuby::DSLs.find_through_method_missing(
        #           self, m, args, '_event' => :find_event) || super
        #      end
        #   end
        #
        module FindThroughMethodMissing
            # Empty implementation of has_through_method_missing? to allow for
            # classes to call 'super'
            def has_through_method_missing?(m)
            end

            # Empty implementation of find_through_method_missing to allow for
            # classes to call 'super'
            def find_through_method_missing(m, args)
            end

            # Resolves the given method using {#has_through_method_missing?}
            def respond_to_missing?(m, include_private)
                has_through_method_missing?(m) || super
            end

            # Resolves the given method using {#find_through_method_missing}
            def method_missing(m, *args, **kw)
                find_args = args
                find_args += [kw] unless kw.empty?
                find_through_method_missing(m, find_args) || super
            end
        end

        # Generic implementation to create suffixed accessors for child objects
        # on a class
        #
        # Given an object category (let's say 'state'), this allows to properly
        # implement a method-missing based accessor of the style
        #
        #     blabla_state
        #
        # using a find_state method that the object should respond to
        #
        # @param [Object] object the object on which the find method is going to
        #   be called
        # @param [Symbol] m the method name
        # @param [Array] args the method arguments
        # @param [{String=>Symbol}] suffix_match the accessor suffixes that
        #   should be resolved, associated with the find method that should be
        #   used to resolve them
        # @return [Object,nil] an object if one of the listed suffixes matches
        #   the method name, or nil if the method name does not match the
        #   requested pattern.
        #
        # @raise [NoMethodError] if the requested object does not exist (i.e. if
        #   the find method returns nil)
        # @raise [ArgumentError] if the method name matches one of the suffixes,
        #   but arguments were given. It is raised regardless of the existence
        #   of the requested object
        #
        # @example
        #   class MyClass
        #     def find_state(name)
        #       states[name]
        #     end
        #     def find_transition(name)
        #       transitions[name]
        #     end
        #     def method_missing(m, *args, &block)
        #       MetaRuby::DSLs.find_through_method_missing(self, m, args,
        #         'state', 'transition') || super
        #     end
        #   end
        #   object = MyClass.new
        #   object.add_state 'my'
        #   object.my_state # will resolve the 'my' state
        #
        def self.find_through_method_missing(object, m, args, suffix_match)
            return false if m == :to_ary

            m = m.to_s
            suffix_match.each do |s, find_method_name|
                if m.end_with?(s)
                    name = m[0, m.size - s.size]
                    if !args.empty?
                        raise ArgumentError,
                              "expected zero arguments to #{m}, got #{args.size}",
                              caller(4)
                    else
                        return object.send(find_method_name, name)
                    end
                end
            end
            nil
        end

        def self.has_through_method_missing?(object, m, suffix_match)
            return false if m == :to_ary

            m = m.to_s
            suffix_match.each do |s, has_method_name|
                if m.end_with?(s)
                    name = m[0, m.size - s.size]
                    return !!object.send(has_method_name, name)
                end
            end
            false
        end
    end
end
