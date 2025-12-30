# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        # @api private
        #
        # Implementation of inherited_attribute in the map case
        module Map
            INVALIDATED = Object.new.freeze
            INVALIDATED_REF = "MetaRuby::InheritedAttributes::Map::INVALIDATED"

            CacheStats = Struct.new :hit, :miss, :miss_locations, keyword_init: true do
                def register_miss(entries)
                    self.miss += 1
                    entries.each do |entry|
                        miss_locations[entry] = (miss_locations[entry] || 0) + 1
                    end
                end

                def pretty_print(pp)
                    pp.text "hit=#{hit} miss=#{miss}"
                    miss_locations.sort_by(&:last).each do |path, count|
                        pp.breakable
                        pp.text "  #{count} #{path}"
                    end
                end
            end

            def self.cache_stats
                @cache_stats
            end

            def self.cache_stats_enabled?
                ENV["METARUBY_CACHE_STATS_ENABLED"] == "1"
            end

            if cache_stats_enabled?
                @cache_stats = CacheStats.new(hit: 0, miss: 0, miss_locations: {})
            end

            CACHE_HIT =
                if cache_stats_enabled?
                    "MetaRuby::InheritedAttributes::Map.cache_stats.hit += 1"
                end

            CACHE_MISS =
                if cache_stats_enabled?
                    "MetaRuby::InheritedAttributes::Map." \
                        "cache_stats.register_miss(caller[0, 5])"
                end

            def self.cache_define_common(mod, name, ivar)
                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def __metaruby_cache_invalidate_#{name}
                        __metaruby_discover_#{name}_keys

                        each_direct_submodel(&:__metaruby_cache_invalidate_#{name})
                    end

                    def __metaruby_discover_#{name}_keys
                        @#{ivar}_cache = @#{ivar}.dup

                        s = supermodel
                        unless s.respond_to?(:__metaruby_discover_#{name}_keys)
                            return @#{ivar}_cache.keys
                        end

                        cache = @#{ivar}_cache
                        s.__metaruby_discover_#{name}_keys.each do |k|
                            cache[k] = #{INVALIDATED_REF} unless cache.key?(k)
                        end

                        cache.keys
                    end

                    def __metaruby_cache_sync_#{name}_key(key)
                        if @#{ivar}.key?(key)
                            each_direct_submodel do
                                _1.__metaruby_cache_#{name}_set(key, @#{ivar}[key])
                            end
                            return true
                        end

                        s = supermodel
                        if s.respond_to?(:__metaruby_cache_sync_#{name}_key)
                            return if s.__metaruby_cache_sync_#{name}_key(key)
                        end

                        each_direct_submodel do
                            _1.__metaruby_cache_#{name}_delete(key)
                        end
                    end

                    def __metaruby_cache_#{name}_delete(key)
                        return if @#{ivar}.key?(key)

                        @#{ivar}_cache.delete(key)
                        each_direct_submodel do
                            _1.__metaruby_cache_#{name}_delete(key)
                        end
                    end

                    def has_#{name}?(key)
                        @#{ivar}_cache.key?(key)
                    end

                    def each_#{name}_keys(&block)
                        @#{ivar}_cache.each_key(&block)
                    end

                    def find_#{name}(key)
                        return unless @#{ivar}_cache.key?(key)

                        @#{ivar}_cache[key] = __metaruby_find_#{name}(key)
                    end

                    def each_#{name}
                        return enum_for(:each_#{name}) unless block_given?

                        new_values = {}
                        @#{ivar}_cache.each do |k, v|
                            if v == #{INVALIDATED_REF}
                                v = __metaruby_find_#{name}(k)
                                new_values[k] = v
                            end
                            yield(k, v)
                        end

                        self
                    ensure
                        @#{ivar}_cache.merge!(new_values) if new_values
                    end
                CODE
            end

            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is set and there is not promotion method
            def self.cache_without_promotion(mod, name, ivar)
                cache_define_common(mod, name, ivar)

                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def __metaruby_cache_#{name}_set(key, value)
                        return if @#{ivar}.key?(key)

                        @#{ivar}_cache[key] = value
                        each_direct_submodel do
                            _1.__metaruby_cache_#{name}_set(key, value)
                        end
                    end

                    def __metaruby_find_#{name}(key)
                        return unless @#{ivar}_cache.key?(key)

                        v = @#{ivar}_cache[key]
                        if v != #{INVALIDATED_REF}
                            #{CACHE_HIT}
                            return v
                        end

                        #{CACHE_MISS}

                        supermodel.find_#{name}(key)
                    end
                CODE
            end

            # @api private
            #
            # Helper class that defines the iteration method for inherited_attribute
            # when :map is set and there is a promotion method
            def self.cache_with_promotion(mod, name, ivar)
                cache_define_common(mod, name, ivar)

                mod.class_eval <<~CODE, __FILE__, __LINE__ + 1
                    def __metaruby_cache_#{name}_set(key, value)
                        return if @#{ivar}.key?(key)

                        @#{ivar}_cache[key] = #{INVALIDATED_REF}
                        each_direct_submodel do
                            _1.__metaruby_cache_#{name}_set(key, value)
                        end
                    end

                    def __metaruby_find_#{name}(key)
                        return unless @#{ivar}_cache.key?(key)

                        v = @#{ivar}_cache[key]
                        if v != #{INVALIDATED_REF}
                            #{CACHE_HIT}
                            return v
                        end

                        #{CACHE_MISS}
                        promote_#{name}(key, supermodel.find_#{name}(key))
                    end
                CODE
            end
        end
    end
end
