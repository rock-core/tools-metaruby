# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the non-map case
        module Enumerable
            def self.define(mod, name, attribute_name, promote:, enum_with:)
                mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
                def #{attribute_name}
                    @#{attribute_name} ||= #{attribute_name}_default
                end
                def has_#{name}?(key)
                    each_#{name}.any? { |obj| obj == key }
                end
                CODE

                if promote
                    no_cache_with_promotion(
                        mod, name, attribute_name, enum_with: enum_with
                    )
                else
                    no_cache_without_promotion(
                        mod, name, attribute_name, enum_with: enum_with
                    )
                end
            end
        end
    end
end
