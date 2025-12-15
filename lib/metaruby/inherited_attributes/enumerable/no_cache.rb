# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the non-map case
        module Enumerable
            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is not set and there is no promotion method
            def self.no_cache_without_promotion(
                mod, name, ivar, enum_with:
            )
                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def each_#{name}
                        return enum_for(__method__) unless block_given?

                        #{ANCESTORS_ACCESS}
                        for klass in ancestors
                            if attr = klass.instance_variable_get(:@#{ivar})
                                attr.#{enum_with} { |el| yield(el) }
                            end
                        end
                        self
                    end
                CODE
            end

            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is not set and there is a promotion method
            def self.no_cache_with_promotion(mod, name, ivar, enum_with:)
                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def each_#{name}
                        return enum_for(:each_#{name}) unless block_given?

                        #{ANCESTORS_ACCESS}
                        promotions = []
                        for klass in ancestors
                            if attr = klass.instance_variable_get(:@#{ivar})
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
                CODE
            end
        end
    end
end
