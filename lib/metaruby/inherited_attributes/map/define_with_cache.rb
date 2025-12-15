# frozen_string_literal: true

# Our own backport, copied from the `backports` gem because of
# https://github.com/marcandre/backports/pull/199
#
# Switch back to using backport when the PR is merged and released
unless Class.method_defined? :attached_object
    class Class # :nodoc:
        def attached_object
            raise TypeError, "`#{self}' is not a singleton class" unless singleton_class?

            ObjectSpace.each_object(self).first
        end
    end
end

require "backports/3.2.0/class/attached_object"

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the map case
        module Map
            def self.define_with_cache(target, name, attribute_name, ivar, promote:)
                mod = Module.new
                mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
                def __metaruby_inherited_attributes_initialize
                    @#{ivar} = #{ivar}_default
                    __metaruby_discover_#{name}_keys
                end

                def self_#{attribute_name}
                    @#{ivar}
                end

                def #{name}_get(key)
                    if (h = @#{ivar})
                        h[key]
                    end
                end

                def #{name}_set(key, value)
                    @#{ivar}[key] = value
                    @#{ivar}_cache[key] = value

                    each_direct_submodel do
                        _1.__metaruby_cache_#{name}_set(key, value)
                    end
                end

                def #{name}_delete(key)
                    return unless @#{ivar}.key?(key)

                    @#{ivar}.delete(key)
                    @#{ivar}_cache.delete(key)

                    __metaruby_cache_sync_#{name}_key(key)
                end

                def #{attribute_name}_update
                    @#{ivar} = yield(@#{ivar})
                    __metaruby_cache_invalidate_#{name}
                    each_direct_submodel(&:__metaruby_cache_invalidate_#{name})
                end
                CODE

                if promote
                    cache_with_promotion(mod, name, ivar)
                else
                    cache_without_promotion(mod, name, ivar)
                end

                apply_extension_modules(target, mod)
            end

            # Apply our definition module as well as the required hooks (to propagate
            # attributes through include/extend/subclassing and singleton class)
            #
            # The way these modules need to be "propagated" depends on the kind of target
            # (module, class, singleton class or singleton class-of-class)
            def self.apply_extension_modules(target, mod)
                if target.kind_of?(Class) && (target <= Class)
                    # singleton class of a class, need to treat the underlying
                    # object as a class (mostly, no need to overload singleton_class)
                    underlying_class = target.attached_object
                    underlying_class.extend mod
                    underlying_class.extend Initialization::Inherited
                    underlying_class.include Initialization::SingletonClass
                    underlying_class.__metaruby_inherited_attributes_initialize
                elsif target.kind_of?(Class)
                    target.extend mod
                    target.extend Initialization::Inherited
                    target.include Initialization::SingletonClass
                    target.__metaruby_inherited_attributes_initialize
                else
                    target.include mod
                    target.extend Initialization::Included
                    target.extend Initialization::Extended
                end
            end

            # @api private
            #
            # Implementation of auto-initialization of instance variables on classes
            # that use inherited_attributes
            #
            # The various modules are here to handle different cases. Each module has
            # a description of the case it handels
            module Initialization
                # Handling of extension of a module/class from a module in which at least
                # one inherited_attribute has been defined
                #
                # If used to extend a class, the module makes sure the class has
                # its instance variables initialized, and that subclasses will be
                # initialized as well. It also overloads {#singleton_class} to
                # handle the class' instances singleton classes (whose creation does
                # not trigger the regular subclass hook)
                module Extended
                    def extended(mod)
                        super

                        if mod.kind_of?(Class)
                            # Define the 'inherited' hook so that the subclasses
                            # have had their __metaruby_inherited_attributes_initialize
                            # method called
                            mod.extend Inherited

                            # Overload #singleton_class to initialize it on first creation
                            mod.include SingletonClass
                        end
                        mod.__metaruby_inherited_attributes_initialize
                    end
                end

                # Handling of having a module that defines inherited attributes included
                # in another
                #
                # It defines the hooks necessary for the "new" module to provide
                # initialization features
                module Included
                    def included(mod)
                        super

                        mod.extend Extended
                        mod.extend Included
                    end
                end

                # Overload of Object#singleton_class to initialize inherited attributes
                # once on singleton class creation
                module SingletonClass
                    def singleton_class
                        s = super
                        return s if @__metaruby_singleton_initialized

                        s.__metaruby_inherited_attributes_initialize
                        @__metaruby_singleton_initialized = true
                        s
                    end
                end

                # Handling of subclassing
                module Inherited
                    def inherited(subclass)
                        super

                        subclass.__metaruby_inherited_attributes_initialize
                    end
                end
            end
        end
    end
end
