require "facets/module/spacename"
require "facets/module/basename"
require "utilrb/object/attribute"
require "utilrb/module/attr_predicate"

module MetaRuby
    # Handling of registration of model hierarchies
    #
    # It depends on the mixed-in object to provide a #supermodel method that
    # returns the model that is parent of +self+
    module Registration
        # The place where this model got defined in the source code
        # This is an array of Thread::Backtrace::Locations
        #
        # @return [Array<Thread::Backtrace::Locations>]
        attr_accessor :definition_location

        # Tells {#clear_submodels} whether this model should be removed from
        # the model set or not. The default is false (it should be removed)
        #
        # @return [Boolean]
        attr_predicate :permanent_model?, true

        # @api private
        #
        # @return [Array<WeakRef>] the set of models that are children of this one
        attribute(:submodels) { [] }

        # Returns whether a model is a submodel of self
        def has_submodel?(model)
            each_submodel.any? { |m| m == model }
        end

        # @return [Boolean] true if the definition context (module, class) in
        #   which self is registered is permanent or not w.r.t. the model
        #   registration functionality of metaruby
        def permanent_definition_context?
            return false unless name

            definition_context_name = spacename
            if definition_context_name.empty?
                true
            else
                begin
                    enclosing_context = constant("::#{definition_context_name}")
                    !enclosing_context.respond_to?(:permanent_model?) || enclosing_context.permanent_model?
                rescue NameError
                    false
                end
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
            if klass.singleton_class?
                raise ArgumentError, "cannot register a singleton class"
            end

            unless klass.definition_location
                klass.definition_location =
                    if MetaRuby.keep_definition_location?
                        caller_locations
                    else
                        []
                    end
            end

            submodels << WeakRef.new(klass)
            return unless m = supermodel

            m.register_submodel(klass)
        end

        # Enumerates all models that are submodels of this class
        def each_submodel
            return enum_for(:each_submodel) unless block_given?

            submodels.delete_if do |obj|
                yield(obj.__getobj__)
                false
            rescue WeakRef::RefError
                true
            end
        end

        # Clears this model
        #
        # It deregisters sef if it is not a {#permanent_model?}, and clears the
        # submodels
        #
        # Model classes and modules should also clear their respective
        # attributes (if there are any)
        def clear_model
            unless permanent_model?
                if m = supermodel
                    m.deregister_submodels([self])
                end
                clear_registration_as_constant
            end
            clear_submodels
        end

        # Removes any constant this model is registered as
        def clear_registration_as_constant
            # Deregister non-permanent models that are registered in the
            # constant hierarchy
            return unless Registration.accessible_by_name?(self)

            Registration.deregister_constant(self)
        end

        # Removes the constant that stores the given object in the Ruby constant
        # hierarchy
        #
        # It assumes that calling #name on the object returns the place in the
        # constant hierarchy where it is stored
        def self.deregister_constant(obj)
            constant("::#{obj.spacename}").send(:remove_const, obj.basename)
        end

        # Recursively deregisters all non-permanent submodels
        def clear_submodels
            permanent, non_permanent = each_submodel.partition { |m| m.permanent_model? }
            deregister_submodels(non_permanent) unless non_permanent.empty?

            non_permanent.each do |m|
                m.clear_registration_as_constant
            end

            # This contains the permanent submodels
            #
            # We can call #clear_submodels while iterating here as it is a
            # constraint that all models in #submodels are permanent (and
            # will therefore not be removed)
            permanent.each { |m| m.clear_submodels }
            # And this the non-permanent ones
            non_permanent.each { |m| m.clear_submodels }
            true
        end

        # @api private
        #
        # Deregisters a set of submodels on this model and all its
        # supermodels
        #
        # This is usually not called directly. Use #clear_submodels instead
        #
        # @param [Set] set the set of submodels to remove
        def deregister_submodels(set)
            has_match = false
            submodels.delete_if do |m|
                m = m.__getobj__
                has_match = true if set.include?(m)
            rescue WeakRef::RefError
                true
            end

            if m = supermodel
                m.deregister_submodels(set)
            end
            has_match
        end
    end
end
