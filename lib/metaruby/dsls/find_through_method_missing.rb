module MetaRuby
    module DSLs
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
        # @param [Array<String>] suffixes the accessor suffixes that should be
        #   resolved
        # @return [Object,nil] an object if one of the listed suffixes matches
        #   the method name, or nil if the method name does not match the
        #   requested pattern.
        #
        # @raise [NoMethodError] if the requested object does not exist (i.e. if
        #   the find method returns nil)
        # @raise [ArgumentError] if the method name matches one of the suffixes,
        #   but arguments were given
        #
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
        def self.find_through_method_missing(object, m, args, *suffixes)
            m = m.to_s
            suffixes.each do |s|
                find_method_name = "find_#{s}"
                if m == find_method_name
                    raise NoMethodError.new("#{object} has no method called #{find_method_name}", m)
                elsif m =~ /(.*)_#{s}$/
                    name = $1
                    if found = object.send(find_method_name, name)
                        if !args.empty?
                            raise ArgumentError, "expected zero arguments to #{m}, got #{args.size}", caller(4)
                        else return found
                        end
                    else
                        msg = "#{self} has no #{s} named #{name}"
                        raise NoMethodError.new(msg, m), msg, caller(4)
                    end
                end
            end
            nil
        end
    end
end