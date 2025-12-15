# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_single_value_attribute
        module SingleValue
            def self.define(mod, name, dsl_attribute_name, ivar, promotion_method:)
                if mod.method_defined?(promotion_method)
                    no_cache_with_promotion(
                        mod, "#{dsl_attribute_name}_get", promotion_method, ivar
                    )
                else
                    no_cache_without_promotion(
                        mod, "#{dsl_attribute_name}_get", ivar
                    )
                end

                mod.class_eval <<~EOCODE, __FILE__, __LINE__ + 1
                    def #{name}(*args)
                        if args.empty? # Getter call
                            #{dsl_attribute_name}_get
                        else # Setter call, delegate to the dsl_attribute implementation
                            #{dsl_attribute_name}(*args)
                        end
                    end
                EOCODE
            end
        end
    end
end
