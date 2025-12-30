# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_single_value_attribute
        module SingleValue
            # @api private
            #
            # Helper method for {#inherited_single_value_attribute} in case there
            # are no promotion method(s) defined
            def self.no_cache_without_promotion(mod, method_name, ivar)
                mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
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
                CODE
            end

            # @api private
            #
            # Helper method for {#inherited_single_value_attribute} in case there is
            # a promotion method defined
            def self.no_cache_with_promotion(
                mod, method_name, promotion_method_name, ivar
            )
                mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
                def #{method_name}
                    #{ANCESTORS_ACCESS}

                    promotions = []
                    for klass in ancestors
                        if klass.instance_variable_defined?(:#{ivar})
                            has_value = true
                            value = klass.instance_variable_get(:#{ivar})
                            break
                        end
                        if klass.respond_to?(:#{promotion_method_name})
                            promotions.unshift(klass)
                        end
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
                            if klass.respond_to?(:#{promotion_method_name})
                                promotions.unshift(klass)
                            end
                        end
                        promotions.shift
                        base.instance_variable_set :#{ivar}, value
                    end

                    if has_value
                        promotions.inject(value) { |v, k| k.#{promotion_method_name}(v) }
                    end
                end
                CODE
            end
        end
    end
end
