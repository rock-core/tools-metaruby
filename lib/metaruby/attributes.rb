require "set"
require "utilrb/module/dsl_attribute"
module MetaRuby
    # Basic functionality for attributes that are aware of inheritance
    #
    # There's basically two main interfaces: {.inherited_single_value_attribute}
    # and {.inherited_attribute}.
    #
    # The former will return the value as set at the lowest level in the
    # model hierarchy (i.e. on self, then on supermodel if self is unset and so
    # forth).
    #
    # The latter enumerates a collection (e.g. Array, Set or Hash). If a map
    # is used (such as a Hash), additional functionality gives different choices
    # as to how the key-value mapping is handled w.r.t. model hierarchy.
    #
    # In both cases, a value returned by a submodel is optionally passed through
    # a promotion method (called #promote_#attributename) which allows to update
    # the returned value (as e.g. update a possible back-reference of the
    # enumerated value to its containing model from the original model to the
    # receiver).
    #
    # @example promotion to update back references
    #   class Port; attr_accessor :component_model end
    #   class Component
    #       # Update #component_model to make it point to the receiver instead
    #       # of the original model. Note that metaruby does not memoize the
    #       # result, so it has to be done in the promote method if it is
    #       # desired
    #       def promote_port(port)
    #           port = port.dup
    #           port.component_model = self
    #           port
    #       end
    #
    #       inherited_attribute(:ports, :port, map: true) { Hash.new }
    #   end
    module Attributes
        def included(mod)
            mod.extend Attributes
        end

        # Defines an attribute that holds at most a single value
        #
        # The value returned by the defined accessor will be the one set at the
        # lowest level in the model hierarchy (i.e. self, then superclass, ...)
        #
        # @param [String] name the attribute name
        # @return [InheritedAttribute] the attribute definition
        # @raise [ArgumentError] if no attribute with that name exists
        def inherited_single_value_attribute(name, &default_value)
            dsl_attribute_name = "__dsl_attribute__#{name}"
            ivar = "@#{dsl_attribute_name}"
            dsl_attribute(dsl_attribute_name)
            if default_value
                define_method("#{dsl_attribute_name}_get_default") { default_value }
            end

            promotion_method = "promote_#{name}"
            if method_defined?(promotion_method)
                define_single_value_with_promotion("#{dsl_attribute_name}_get",
                                                   promotion_method, ivar)
            else
                define_single_value_without_promotion("#{dsl_attribute_name}_get", ivar)
            end
            define_method(name) do |*args|
                if args.empty? # Getter call
                    send("#{dsl_attribute_name}_get")
                else # Setter call, delegate to the dsl_attribute implementation
                    send(dsl_attribute_name, *args)
                end
            end
            nil
        end

        ANCESTORS_ACCESS =
            if RUBY_VERSION < "2.1.0"
                <<-EOCODE
                ancestors = self.ancestors
                if ancestors.first != self
                    ancestors.unshift self
                end
                EOCODE
            else
                <<-EOCODE
                ancestors = self.ancestors
                EOCODE
            end

        # @api private
        #
        # Helper method for {#inherited_single_value_attribute} in case there
        # are no promotion method(s) defined
        def define_single_value_without_promotion(method_name, ivar)
            class_eval <<-EOF, __FILE__, __LINE__ + 1
            def #{method_name}
                #{ANCESTORS_ACCESS}

                has_value = false
                for klass in ancestors
                    if klass.instance_variable_defined?(:#{ivar})
                        has_value = true
                        value = klass.instance_variable_get(:#{ivar})
                        break
                    end
                end

                if !has_value && respond_to?(:#{method_name}_default)
                    # Look for default
                    has_value = true
                    value = send(:#{method_name}_default).call
                    base = nil
                    for klass in ancestors
                        if !klass.respond_to?(:#{method_name}_default)
                            break
                        end
                        base = klass
                    end
                    base.instance_variable_set :#{ivar}, value
                end
                value
            end
            EOF
        end

        # @api private
        #
        # Helper method for {#inherited_single_value_attribute} in case there is
        # a promotion method defined
        def define_single_value_with_promotion(method_name, promotion_method_name, ivar)
            class_eval <<-EOF, __FILE__, __LINE__ + 1
            def #{method_name}
                #{ANCESTORS_ACCESS}

                promotions = []
                for klass in ancestors
                    if klass.instance_variable_defined?(:#{ivar})
                        has_value = true
                        value = klass.instance_variable_get(:#{ivar})
                        break
                    end
                    promotions.unshift(klass) if klass.respond_to?(:#{promotion_method_name})
                end
                if !has_value && respond_to?(:#{method_name}_default)
                    # Look for default
                    has_value = true
                    value = send(:#{method_name}_default).call
                    base = nil
                    promotions.clear
                    for klass in ancestors
                        if !klass.respond_to?(:#{method_name}_default)
                            break
                        end
                        base = klass
                        promotions.unshift(klass) if klass.respond_to?(:#{promotion_method_name})
                    end
                    promotions.shift
                    base.instance_variable_set :#{ivar}, value
                end

                if has_value
                    promotions.inject(value) { |v, k| k.#{promotion_method_name}(v) }
                end
            end
            EOF
        end

        # Defines an attribute that holds a set of values, and defines the
        # relevant methods and accessors to allow accessing it in a way that
        # makes sense when embedded in a model hierarchy
        #
        # More specifically, it defines a <tt>each_#name(&iterator)</tt>
        # instance method and a <tt>each_#name(&iterator)</tt>
        # class method which iterates (in order) on
        # - the instance #name attribute
        # - the singleton class #name attribute
        # - the class #name attribute
        # - the superclass #name attribute
        # - the superclass' superclass #name attribute
        # ...
        #
        # This method can be used on modules, in which case the module is used as if
        # it was part of the inheritance hierarchy.
        #
        # The +name+ option defines the enumeration method name (+value+ will
        # define a +each_value+ method). +attribute_name+ defines the attribute
        # name. +init+ is a block called to initialize the attribute.
        # Valid options in +options+ are:
        # map::
        #   If true, the attribute should respond to +[]+. In that case, the
        #   enumeration method is each_value(key = nil, uniq = false) If +key+ is
        #   given, we iterate on the values given by <tt>attribute[key]</tt>. If
        #   +uniq+ is true, the enumeration will yield at most one value for each
        #   +key+ found (so, if both +key+ and +uniq+ are given, the enumeration
        #   yields at most one value). See the examples below
        # enum_with:: the enumeration method of the enumerable, if it is not +each+
        #
        # === Example
        # Let's define some classes and look at the ancestor chain
        #
        #   class A;  end
        #   module M; end
        #   class B < A; include M end
        #   A.ancestors # => [A, Object, Kernel]
        #   B.ancestors # => [B, M, A, Object, Kernel]
        #
        # ==== Attributes for which 'map' is not set
        #
        #   class A
        #     class << self
        #       inherited_attribute("value", "values") do
        #           Array.new
        #       end
        #     end
        #   end
        #   module M
        #     class << self
        #       extend MetaRuby::Attributes
        #       inherited_attribute("mod") do
        #           Array.new
        #       end
        #     end
        #   end
        #
        #   A.values << 1 # => [1]
        #   B.values << 2 # => [2]
        #   M.mod << 1 # => [1]
        #   b = B.new
        #   class << b
        #       self.values << 3 # => [3]
        #       self.mod << 4 # => [4]
        #   end
        #   M.mod << 2 # => [1, 2]
        #
        #   A.enum_for(:each_value).to_a # => [1]
        #   B.enum_for(:each_value).to_a # => [2, 1]
        #   b.singleton_class.enum_for(:each_value).to_a # => [3, 2, 1]
        #   b.singleton_class.enum_for(:each_mod).to_a # => [4, 1, 2]
        #
        # ==== Attributes for which 'map' is set
        #
        #   class A
        #     class << self
        #       inherited_attribute("mapped", "map", :map => true) do
        #           Hash.new { |h, k| h[k] = Array.new }
        #       end
        #     end
        #   end
        #
        #   A.map['name'] = 'A' # => "A"
        #   A.map['universe'] = 42
        #   B.map['name'] = 'B' # => "B"
        #   B.map['half_of_it'] = 21
        #
        # Let's see what happens if we don't specify the key option.
        #   A.enum_for(:each_mapped).to_a # => [["name", "A"], ["universe", 42]]
        # If the +uniq+ option is set (the default), we see only B's value for 'name'
        #   B.enum_for(:each_mapped).to_a # => [["half_of_it", 21], ["name", "B"], ["universe", 42]]
        # If the +uniq+ option is not set, we see both values for 'name'. Note that
        # since 'map' is a Hash, the order of keys in one class is not guaranteed.
        # Nonetheless, we have the guarantee that values from B appear before
        # those from A
        #   B.enum_for(:each_mapped, nil, false).to_a # => [["half_of_it", 21], ["name", "B"], ["name", "A"], ["universe", 42]]
        #
        #
        # Now, let's see how 'key' behaves
        #   A.enum_for(:each_mapped, 'name').to_a # => ["A"]
        #   B.enum_for(:each_mapped, 'name').to_a # => ["B"]
        #   B.enum_for(:each_mapped, 'name', false).to_a # => ["B", "A"]
        #
        def inherited_attribute(name, attribute_name = name, yield_key: true, map: false, enum_with: :each, &init) # :nodoc:
            # Set up the attribute accessor
            attribute(attribute_name, &init)
            class_eval { private "#{attribute_name}=" }

            promote = method_defined?("promote_#{name}")

            class_eval <<-EOF, __FILE__, __LINE__ + 1
            def all_#{name}; each_#{name}.to_a end
            def self_#{name}; @#{attribute_name} end
            EOF

            if map
                class_eval <<-EOF, __FILE__, __LINE__ + 1
                def find_#{name}(key)
                    raise ArgumentError, "nil cannot be used as a key in find_#{name}" if !key
                    each_#{name}(key, true) do |value|
                        return value
                    end
                    nil
                end
                def has_#{name}?(key)
                    #{ANCESTORS_ACCESS}
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            return true if attr.has_key?(key)
                        end
                    end
                    false
                end
                EOF
            else
                class_eval <<-EOF, __FILE__, __LINE__ + 1
                def has_#{name}?(key)
                    each_#{name}.any? { |obj| obj == key }
                end
                EOF
            end

            class_eval <<-EOF, __FILE__, __LINE__ + 1
            def clear_#{attribute_name}
                #{attribute_name}.clear
                for klass in ancestors
                    if attr = klass.instance_variable_get(:@#{attribute_name})
                        attr.clear
                    end
                end
            end
            EOF

            if !promote
                if map
                    class_eval(*Attributes.map_without_promotion(name, attribute_name,
                                                                 yield_key: yield_key, enum_with: enum_with))
                else
                    class_eval(*Attributes.nomap_without_promotion(name, attribute_name,
                                                                   enum_with: enum_with))
                end
            elsif map
                class_eval(*Attributes.map_with_promotion(name, attribute_name,
                                                          yield_key: yield_key, enum_with: enum_with))
            else
                class_eval(*Attributes.nomap_with_promotion(name, attribute_name,
                                                            enum_with: enum_with))
            end
        end

        # @api private
        #
        # Helper class that defines the iteration method for inherited_attribute
        # when :map is set and there is not promotion method
        def self.map_without_promotion(name, attribute_name, yield_key: true, enum_with: :each)
            file = __FILE__
            line = __LINE__ + 2
            code = <<-EOF
            def each_#{name}(key = nil, uniq = true)
                if !block_given?
                    return enum_for(:each_#{name}, key, uniq)
                end

                #{ANCESTORS_ACCESS}
                if key
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            if attr.has_key?(key)
                                yield(attr[key])
                                return self if uniq
                            end
                        end
                    end
                elsif !uniq
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            attr.#{enum_with} do |el|
                                yield(el)
                            end
                        end
                    end
                else
                    seen = Set.new
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            attr.#{enum_with} do |el_key, el|#{' '}
                                if !seen.include?(el_key)
                                    seen << el_key
                                    #{yield_key ? 'yield(el_key, el)' : 'yield(el)'}
                                end
                            end
                        end
                    end

                end
                self
            end
            EOF
            [code, file, line]
        end

        # @api private
        #
        # Helper class that defines the iteration method for inherited_attribute
        # when :map is not set and there is no promotion method
        def self.nomap_without_promotion(name, attribute_name, enum_with: :each)
            file = __FILE__
            line = __LINE__ + 2
            code = <<-EOF
            def each_#{name}
                return enum_for(__method__) if !block_given?

                #{ANCESTORS_ACCESS}
                for klass in ancestors
                    if attr = klass.instance_variable_get(:@#{attribute_name})
                        attr.#{enum_with} { |el| yield(el) }
                    end
                end
                self
            end
            EOF
            [code, file, line]
        end

        # @api private
        #
        # Helper class that defines the iteration method for inherited_attribute
        # when :map is set and there is a promotion method
        def self.map_with_promotion(name, attribute_name, yield_key: true, enum_with: :each)
            file = __FILE__
            line = __LINE__ + 2
            code = <<-EOF
            def each_#{name}(key = nil, uniq = true)
                if !block_given?
                    return enum_for(:each_#{name}, key, uniq)
                end

                #{ANCESTORS_ACCESS}
                if key
                    promotions = []
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            if attr.has_key?(key)
                                value = attr[key]
                                for p in promotions
                                    value = p.promote_#{name}(key, value)
                                end
                                yield(value)
                                return self if uniq
                            end
                        end
                        promotions.unshift(klass) if klass.respond_to?(:promote_#{name})
                    end
                elsif !uniq
                    promotions = []
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            attr.#{enum_with} do |k, v|
                                for p in promotions
                                    v = p.promote_#{name}(k, v)
                                end
                                #{yield_key ? 'yield(k, v)' : 'yield(v)'}
                            end
                        end
                        promotions.unshift(klass) if klass.respond_to?(:promote_#{name})
                    end
                else
                    seen = Set.new
                    promotions = []
                    for klass in ancestors
                        if attr = klass.instance_variable_get(:@#{attribute_name})
                            attr.#{enum_with} do |k, v|
                                unless seen.include?(k)
                                    for p in promotions
                                        v = p.promote_#{name}(k, v)
                                    end
                                    seen << k
                                    #{yield_key ? 'yield(k, v)' : 'yield(v)'}
                                end
                            end
                        end
                        promotions.unshift(klass) if klass.respond_to?(:promote_#{name})
                    end
                end
                self
            end
            EOF
            [code, file, line]
        end

        # @api private
        #
        # Helper class that defines the iteration method for inherited_attribute
        # when :map is not set and there is a promotion method
        def self.nomap_with_promotion(name, attribute_name, enum_with: :each)
            file = __FILE__
            line = __LINE__ + 2
            code = <<-EOF
            def each_#{name}
                if !block_given?
                    return enum_for(:each_#{name})
                end

                #{ANCESTORS_ACCESS}
                promotions = []
                for klass in ancestors
                    if attr = klass.instance_variable_get(:@#{attribute_name})
                        attr.#{enum_with} do |value|
                            for p in promotions
                                value = p.promote_#{name}(value)
                            end
                            yield(value)
                        end
                    end
                    promotions.unshift(klass) if klass.respond_to?(:promote_#{name})
                end
                self
            end
            EOF
            [code, file, line]
        end
    end
end
