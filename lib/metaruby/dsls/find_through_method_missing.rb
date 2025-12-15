require "metaruby/attributes"

module MetaRuby
    module DSLs
        # Common definition of #respond_to_missing? and #method_missing to be
        # used in conjunction with {DSLs.find_through_method_missing} and
        # {DSLs.has_through_method_missing?}
        #
        # When following strict conventions on the naming of the accessors and the
        # suffixes, use {.standard}. Otherwise, you may provide the various methods
        # by hand
        #
        # @example resolve 'event' objects using the .standard definition
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
        #      # This defines that is necessary to access events using <name>_event
        #      # accessors. It relies on the convention that the 'find' method for 'event'
        #      # is 'find_event' and the 'has' method has_event?
        #      MetaRuby::DSLs::FindThroughMethodMissing.standard(self, %w[event])
        #   end
        #
        # @example resolve 'event', the explicit way
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
        #      HAS_THROUGH_METHOD_MISSING = {
        #          "_event" => :has_event?
        #      }.freeze
        #
        #      FIND_THROUGH_METHOD_MISSING = {
        #          "_event" => :find_event
        #      }.freeze
        #
        #      def find_through_method_missing(m, args)
        #          MetaRuby::DSLs.find_through_method_missing(
        #              m, args, FIND_THROUGH_METHOD_MISSING
        #          )
        #      end
        #
        #      def has_through_method_missing(m)
        #          MetaRuby::DSLs.has_through_method_missing(
        #              m, HAS_THROUGH_METHOD_MISSING
        #          )
        #      end
        #
        #      # This defines that is necessary to access events using <name>_event
        #      # accessors. It relies on the convention that the 'find' method for 'event'
        #      # is 'find_event' and the 'has' method has_event?
        #      include MetaRuby::DSLs::FindThroughMethodMissing
        #   end
        #
        module FindThroughMethodMissing
            # Empty implementation of has_through_method_missing? to allow for
            # classes to call 'super'
            def has_through_method_missing?(m); end

            # Empty implementation of find_through_method_missing to allow for
            # classes to call 'super'
            def find_through_method_missing(m, args); end

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

            # All-in-one implementation when following standardized conventions
            #
            # If you are following the pattern `find_OBJECT` and `has_OBJECT?`, then
            # you can use this method to do all the necessary definitions so that OBJECT
            # can be accessed with accessors of the form NAME_suffix:
            #
            #     standard(self, "_suffix" => "OBJECT")
            #
            # In the common case where "suffix" and "OBJECT" are one and the same, the
            # hash can be replaced by an array:
            #
            #     standard(self, %w[OBJECT])
            #
            def self.standard(context, suffix_match)
                if suffix_match.respond_to?(:to_ary)
                    suffix_match = suffix_match.each_with_object({}) do |s, h|
                        h["_#{s}"] = s
                    end
                end

                has_match = suffix_match.transform_values do |v|
                    :"has_#{v}?"
                end
                context.const_set(:HAS_THROUGH_METHOD_MISSING, has_match.freeze)

                find_match = suffix_match.transform_values do |v|
                    :"find_#{v}"
                end
                context.const_set(:FIND_THROUGH_METHOD_MISSING, find_match.freeze)

                context.class_eval <<~SCRIPT, __FILE__, __LINE__ + 1
                    def find_through_method_missing(m, args)
                        MetaRuby::DSLs.find_through_method_missing(
                            self, m, args, FIND_THROUGH_METHOD_MISSING
                        ) || super
                    end

                    def has_through_method_missing?(m)
                        MetaRuby::DSLs.has_through_method_missing?(
                            self, m, HAS_THROUGH_METHOD_MISSING
                        ) || super
                    end
                SCRIPT
                context.include self
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
                next unless m.end_with?(s)

                name = m[0, m.size - s.size]
                unless args.empty?
                    raise ArgumentError,
                          "expected zero arguments to #{m}, got #{args.size}",
                          caller(4)
                end

                return object.send(find_method_name, name)
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
