# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the map case
        module Map
            def self.no_cache_define_common(mod, name, ivar)
                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def each_#{name}_keys
                        return enum_for(:each_#{name}_keys) unless block_given?

                        seen = Set.new
                        for klass in ancestors
                            if (attr = klass.instance_variable_get(:@#{ivar}))
                                attr.each_key do |key|
                                    yield(key) if seen.add?(key)
                                end
                            end
                        end
                    end
                CODE
            end

            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is set and there is not promotion method
            def self.no_cache_without_promotion(
                mod, name, ivar, yield_key:, enum_with:
            )
                no_cache_define_common(mod, name, ivar)

                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def each_#{name}(key = nil, uniq = true)
                        if !block_given?
                            return enum_for(:each_#{name}, key, uniq)
                        end

                        #{ANCESTORS_ACCESS}
                        if key
                            for klass in ancestors
                                if attr = klass.instance_variable_get(:@#{ivar})
                                    if attr.key?(key)
                                        yield(attr[key])
                                        return self if uniq
                                    end
                                end
                            end
                        elsif !uniq
                            for klass in ancestors
                                if attr = klass.instance_variable_get(:@#{ivar})
                                    attr.#{enum_with} do |el|
                                        yield(el)
                                    end
                                end
                            end
                        else
                            seen = Set.new
                            for klass in ancestors
                                if attr = klass.instance_variable_get(:@#{ivar})
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
                CODE
            end

            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is set and there is a promotion method
            def self.no_cache_with_promotion(
                mod, name, ivar, yield_key:, enum_with:
            )
                no_cache_define_common(mod, name, ivar)

                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def each_#{name}(key = nil, uniq = true)
                        if !block_given?
                            return enum_for(:each_#{name}, key, uniq)
                        end

                        #{ANCESTORS_ACCESS}
                        if key
                            promotions = []
                            for klass in ancestors
                                if attr = klass.instance_variable_get(:@#{ivar})
                                    if attr.key?(key)
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
                                if attr = klass.instance_variable_get(:@#{ivar})
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
                                if attr = klass.instance_variable_get(:@#{ivar})
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
                CODE
            end
        end
    end
end
