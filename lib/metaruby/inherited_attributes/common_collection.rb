# frozen_string_literal: true

module MetaRuby
    # @api private
    #
    # Implementation methods for MetaRuby::Attributed
    module InheritedAttributes
        def self.common_collection(
            target, name, attribute_name, ivar, init
        )
            mod =
                if target.kind_of?(Class) && !(target <= Class)
                    target.singleton_class
                else
                    target
                end

            mod.define_method("#{ivar}_default", &init)

            mod.class_eval <<-CODE, __FILE__, __LINE__ + 1
            def __metaruby_inherited_attributes_initialize
                super

                @#{ivar} = #{ivar}_default
            end
            def all_#{name}; each_#{name}.to_a end
            def clear_#{attribute_name}
                @#{ivar}&.clear
                for klass in ancestors
                    if attr = klass.instance_variable_get(:@#{ivar})
                        attr.clear
                    end
                end
            end

            def #{attribute_name}_clear
                @#{ivar}&.clear
            end
            CODE
        end
    end
end
