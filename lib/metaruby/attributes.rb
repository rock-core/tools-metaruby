# frozen_string_literal: true

require "set"
require "utilrb/module/dsl_attribute"

require "metaruby/inherited_attributes/common_collection"
require "metaruby/inherited_attributes/ancestors_access"
require "metaruby/inherited_attributes/single_value/define"
require "metaruby/inherited_attributes/single_value/no_cache"
require "metaruby/inherited_attributes/enumerable/define"
require "metaruby/inherited_attributes/enumerable/no_cache"
require "metaruby/inherited_attributes/map/define"
require "metaruby/inherited_attributes/map/no_cache"
require "metaruby/inherited_attributes/map/define_with_cache"
require "metaruby/inherited_attributes/map/cache"
require "metaruby/inherited_attributes/map/validate_cache_args"

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
            super

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

            InheritedAttributes::SingleValue.define(
                self, name, dsl_attribute_name, ivar,
                promotion_method: "promote_#{name}"
            )
            nil
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
        #   B.each_mapped(nil, false).to_a # => [["half_of_it", 21], ["name", "B"], ["name", "A"], ["universe", 42]]
        #
        #
        # Now, let's see how 'key' behaves
        #   A.each_mapped('name').to_a # => ["A"]
        #   B.each_mapped('name').to_a # => ["B"]
        #   B.each_mapped('name', false).to_a # => ["B", "A"]
        #
        def inherited_attribute( # rubocop:disable Metrics/ParameterLists
            name, attribute_name = name,
            yield_key: true, map: false, enum_with: :each, cache: false, &init
        )
            ivar =
                if cache
                    "__metaruby_#{name}"
                else
                    attribute_name
                end

            InheritedAttributes.common_collection(self, name, attribute_name, ivar, init)

            promote = method_defined?("promote_#{name}")
            if cache
                InheritedAttributes::Map
                    .validate_cache_args(map: map, enum_with: enum_with)
                InheritedAttributes::Map.define_with_cache(
                    self, name, attribute_name, ivar, promote: promote
                )
            elsif map
                InheritedAttributes::Map.define(
                    self, name, attribute_name, ivar,
                    promote: promote, yield_key: yield_key, enum_with: enum_with
                )
            else
                InheritedAttributes::Enumerable.define(
                    self, name, ivar,
                    promote: promote, enum_with: enum_with
                )
            end
        end
    end
end
