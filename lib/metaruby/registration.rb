require 'facets/kernel/call_stack'
require 'utilrb/object/attribute'
require 'utilrb/module/attr_predicate'
module MetaRuby
    # Handling of registration of model hierarchies
    #
    # It depends on the mixed-in object to provide a #supermodel method that
    # returns the model that is parent of +self+
    module Registration
        # The place where this model got defined in the source code
        # The tuple is (file,lineno,method), and can be obtained with
        # facet's #call_stack
        # @return [Array<(String,Integer,Symbol)>]
        attr_accessor :definition_location

        # Tells {#clear_submodels} whether this model should be removed from
        # the model set or not. The default is false (it should be removed)
        #
        # @return [Boolean]
        attr_predicate :permanent_model?, true

        # [ValueSet] the set of models that are children of this one
        attribute(:submodels) { ValueSet.new }

        # Returns the model that is parent of this one
        #
        # The default implementation returns superclass if it is extended by
        # this Registration module, and nil otherwise
        def supermodel
            if superclass.respond_to?(:register_submodel)
                superclass
            end
        end

        # Call to register a model that is a submodel of +self+
        def register_submodel(klass)
            if !klass.definition_location
                klass.definition_location = call_stack
            end

            if klass.name && !klass.permanent_model?
                begin
                    if constant("::#{klass.name}") == klass
                        klass.permanent_model = true
                    end
                rescue NameError
                end
            end

            submodels << klass
            if m = supermodel
                m.register_submodel(klass)
            end
        end

        # Enumerates all models that are submodels of this class
        def each_submodel
            return enum_for(:each_submodel) if !block_given?
            submodels.each do |obj|
                yield(obj)
            end
        end

        def clear_model
            if m = supermodel
                m.deregister_submodels([self])
            end
            submodels.clear
        end

        # Clears all registered submodels
        def clear_submodels
            children = self.submodels.find_all { |m| !m.permanent_model? }
            deregister_submodels(children)

            children.each do |m|
                # Deregister non-permanent models that are registered in the
                # constant hierarchy
                valid_name = begin constant(m.name) == m
                             rescue NameError
                             end

                if valid_name
                    parent_module = if m.name =~ /::/
                                        constant(m.name.gsub(/::[^:]*$/, ''))
                                    else Object
                                    end
                    parent_module.send(:remove_const, m.name.gsub(/.*::/, ''))
                end
            end

            # This contains the permanent submodels
            #
            # We can call #clear_submodels while iterating here as it is a
            # constraint that all models in #submodels are permanent (and
            # will therefore not be removed)
            submodels.each { |m| m.clear_submodels }
            # And this the non-permanent ones
            children.each { |m| m.clear_submodels }
            true
        end

        # Deregisters a set of submodels on this model and all its
        # supermodels
        #
        # This is usually not called directly. Use #clear_submodels instead
        #
        # @param [ValueSet] set the set of submodels to remove
        def deregister_submodels(set)
            current_size = submodels.size
            submodels.difference!(set.to_value_set)
            if m = supermodel
                m.deregister_submodels(set)
            end
        end
    end
end



