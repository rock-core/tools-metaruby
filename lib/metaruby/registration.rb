require 'facets/module/spacename'
require 'facets/module/basename'
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

        # @return [Boolean] true if the definition context (module, class) in
        #   which self is registered is permanent or not w.r.t. the model
        #   registration functionality of metaruby
        def permanent_definition_context?
            return false if !name
            definition_context_name = spacename
            if !definition_context_name.empty?
                begin
                    enclosing_context = constant("::#{definition_context_name}")
                    return !enclosing_context.respond_to?(:permanent_model?) || enclosing_context.permanent_model?
                rescue NameError
                    false
                end
            else
                true
            end
        end

        # @return [Boolean] true if the given object can be accessed by resolving its
        #   name as a constant
        def self.accessible_by_name?(object)
            return false if !object.respond_to?(:name) || !object.name
            begin
                constant("::#{object.name}") == object
            rescue NameError
                false
            end
        end

        # @return [Boolean] true if this object can be accessed by resolving its
        #   name as a constant
        def accessible_by_name?
            Registration.accessible_by_name?(self)
        end

        # Call to register a model that is a submodel of +self+
        def register_submodel(klass)
            if !klass.definition_location
                klass.definition_location = call_stack
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
            if !permanent_model?
                if m = supermodel
                    m.deregister_submodels([self])
                end
                if Registration.accessible_by_name?(self)
                    Registration.deregister_constant(self)
                end
            end
            clear_submodels
        end
        
        # Removes the constant that stores the given object in the Ruby constant
        # hierarchy
        #
        # It assumes that calling #name on the object returns the place in the
        # constant hierarchy where it is stored
        def self.deregister_constant(obj)
            constant("::#{obj.spacename}").send(:remove_const, obj.basename)
        end

        # Clears all registered submodels
        def clear_submodels
            children = self.submodels.find_all { |m| !m.permanent_model? }
            if !children.empty?
                deregister_submodels(children)
            end

            children.each do |m|
                # Deregister non-permanent models that are registered in the
                # constant hierarchy
                if Registration.accessible_by_name?(m)
                    Registration.deregister_constant(m)
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
            current_size != submodels.size
        end
    end
end



