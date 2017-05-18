require 'metaruby/attributes'

module MetaRuby
    module DSLs
        # Module that is included in classes that
        # DSLs.setup_find_through_method_missing
        module FindThroughMethodMissing
            def find_through_method_missing(m, args, call: true)
                return false if m == :to_ary
                matcher, suffix_to_method = *singleton_class.metaruby_find_through_method_missing_all_suffixes
                if m =~ matcher
                    suffix      = $&
                    object_name = $`

                    if !args.empty?
                        raise ArgumentError, "expected zero arguments to #{m}, got #{args.size}", caller(4)
                    end

                    find_method = suffix_to_method[suffix]
                    if found = public_send(find_method, object_name)
                        return found
                    elsif call
                        msg = "#{self} has no #{suffix[1..-1]} named #{object_name}"
                        raise NoMethodError.new(msg, m), msg, caller(4)
                    else return
                    end
                end
            end

            def respond_to_missing?(m, include_private)
                !!find_through_method_missing(m, [], call: false) || super
            end

            def method_missing(m, *args, &block)
                find_through_method_missing(m, args, call: true) || super
            end

            module ClassExtension
                extend Attributes
                inherited_attribute(:metaruby_find_through_method_missing_suffix, :metaruby_find_through_method_missing_suffixes, map: true) { Hash.new }
                def metaruby_find_through_method_missing_all_suffixes
                    if @__metaruby_find_through_method_missing_all_suffixes
                        return @__metaruby_find_through_method_missing_all_suffixes
                    elsif !@metaruby_find_through_method_missing_suffixes
                        return @__metaruby_find_through_method_missing_all_suffixes = superclass.metaruby_find_through_method_missing_all_suffixes
                    end

                    suffix_to_method = Hash.new
                    matcher = []
                    each_metaruby_find_through_method_missing_suffix do |suffix, find_m|
                        suffix = "_#{suffix}"
                        matcher << suffix
                        suffix_to_method[suffix] = find_m.to_sym
                    end
                    @__metaruby_find_through_method_missing_all_suffixes =
                        [Regexp.new(matcher.join("$|") + "$"), suffix_to_method]
                end
            end
        end
    
        def self.setup_find_through_method_missing(klass, **suffixes)
            if !(klass < FindThroughMethodMissing::ClassExtension)
                 klass.extend FindThroughMethodMissing::ClassExtension
                 klass.include FindThroughMethodMissing
            end
            suffixes.each do |suffix, find_method|
                if !klass.method_defined?(find_method)
                    raise ArgumentError, "find method '#{find_method}' listed for '#{suffix}' does not exist"
                end
            end
            suffixes.each do |suffix, find_method|
                klass.metaruby_find_through_method_missing_suffixes[suffix.to_s] = find_method.to_sym
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
        # @param [Array<String>] suffixes the accessor suffixes that should be
        #   resolved. The last argument can be a hash, in which case the keys
        #   are used as suffixes and the values are the name of the find methods
        #   that should be used.
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
        def self.find_through_method_missing(object, m, args, *suffixes, call: true)
            return false if m == :to_ary

            suffix_match = Hash.new
            if suffixes.last.kind_of?(Hash)
                suffix_match.merge!(suffixes.pop)
            end
            suffixes.each do |name|
                suffix_match[name] = "find_#{name}"
            end

            suffix_match.each do |s, find_method_name|
                if m == find_method_name.to_sym
                    raise NoMethodError.new("#{object} has no method called #{find_method_name}", m)
                elsif m =~ /(.*)_#{s}$/
                    name = $1
                    if !args.empty?
                        raise ArgumentError, "expected zero arguments to #{m}, got #{args.size}", caller(4)
                    elsif found = object.send(find_method_name, name)
                        return found
                    elsif call
                        msg = "#{object} has no #{s} named #{name}"
                        raise NoMethodError.new(msg, m), msg, caller(4)
                    else return
                    end
                end
            end
            nil
        end
    end
end
