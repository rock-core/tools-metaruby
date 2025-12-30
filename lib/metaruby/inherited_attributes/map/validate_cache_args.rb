# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        module Map
            # Helper for MetaRuby::Attributes.inherited_attributes to validate arguments
            # when `cache: true` is set
            def self.validate_cache_args(map:, enum_with:)
                if !map
                    raise ArgumentError, "caching is available only with `map: true`"
                elsif enum_with != :each
                    raise ArgumentError, "caching does not support setting `enum_with`"
                end
            end
        end
    end
end
