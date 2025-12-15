# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the map case
        module Map
            def self.define( # rubocop:disable Metrics/ParameterLists
                target, name, attribute_name, ivar, promote:, yield_key:, enum_with:
            )
                mod =
                    if target.kind_of?(Class) && !(target <= Class)
                        # Class, but not singleton class of a class
                        target.singleton_class
                    else
                        target
                    end

                mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
                def #{attribute_name}
                    @#{ivar} ||= #{ivar}_default
                end

                def self_#{attribute_name}
                    @#{ivar} ||= #{ivar}_default
                end

                def #{name}_get(key)
                    @#{ivar}&.fetch(key, nil)
                end

                def #{name}_set(key, value)
                    (@#{ivar} ||= #{ivar}_default)[key] = value
                end

                def #{name}_delete(key)
                    @#{ivar}&.delete(key)
                end

                def find_#{name}(key)
                    unless key
                        raise ArgumentError, "nil cannot be used as a key in find_#{name}"
                    end

                    each_#{name}(key, true) do |value|
                        return value
                    end
                    nil
                end

                def #{attribute_name}_update
                    @#{ivar} =
                        if (current = @#{ivar})
                            yield(current)
                        else
                            yield(#{ivar}_default)
                        end
                end

                def has_#{name}?(key)
                    #{ANCESTORS_ACCESS}
                    for klass in ancestors
                        if (attr = klass.instance_variable_get(:@#{ivar}))
                            return true if attr.key?(key)
                        end
                    end
                    false
                end
                CODE

                if promote
                    no_cache_with_promotion(
                        mod, name, ivar,
                        yield_key: yield_key, enum_with: enum_with
                    )
                else
                    no_cache_without_promotion(
                        mod, name, ivar,
                        yield_key: yield_key, enum_with: enum_with
                    )
                end
            end
        end
    end
end
