require 'utilrb/module/const_defined_here_p'

module MetaRuby
    # Extend in modules that are used as models
    #
    # @example
    #   module MyBaseModel
    #     extend MetaRuby::ModelAsModule
    #   end
    #
    # Alternatively, one can create a module to describe the metamodel for our
    # base model and then include it in the actual root model
    #
    # @example
    #   module MyBaseMetamodel
    #     include MetaRuby::ModelAsModule
    #   end
    #   module MyBaseModel
    #     extend MyBaseMetamodel
    #   end
    #
    module ModelAsModule
        include Attributes
        include Registration
        extend Attributes

        # @!method doc
        #   @overload doc
        #     @return [String] the documentation text for this model
        #   @overload doc(new_doc)
        #     @param [String] new_doc the new documentation
        #     @return [String] the documentation text for this model
        inherited_single_value_attribute :doc

        # Validate that a string can be used as a constant name
        #
        # @param [String] name the name to validate
        # @raise [ArgumentError] if the name cannot be used as a constant name
        def self.validate_constant_name(name)
            if name !~ /^[A-Z]\w+$/
                raise ArgumentError, "#{name} is not a valid model name"
            end
        end

        # Common method that can be used to create and register a
        # submodel-as-a-module on a provided namespace
        #
        # It is usually used to create specific DSL-like methods that allow to
        # create these models
        #
        # @param [Module,Class] namespace
        # @param [String] name the model name, it must be valid for a Ruby
        #   constant name
        # @param [Module] base_model the base model, which should include
        #   {ModelAsModule} itself
        # @param [Array] args additional arguments to pass to base_model's
        #   #setup_submodel
        # @param [#call] block block passed to base_model's #setup_submodel
        # @return [Module] the new model
        def self.create_and_register_submodel(namespace, name, base_model, *args, &block)
            ModelAsModule.validate_constant_name(name)

            if namespace.const_defined_here?(name)
                model = namespace.const_get(name)
                base_model.setup_submodel(model, *args, &block)
            else 
                namespace.const_set(name, model = base_model.new_submodel(*args, &block))
                model.permanent_model = if !namespace.respond_to?(:permanent_model?)
                                            Registration.accessible_by_name?(namespace)
                                        else namespace.permanent_model?
                                        end
            end

            model
        end

        # The call trace at the point of definition. It is usually used to
        # report to the user in which file this model got defined
        #
        # @return [Array[(String,Integer,Symbol)]] a list of (file,line,method)
        #   tuples as returned by #call_stack (from the facet gem)
        attr_accessor :definition_location

        # Set of models that this model provides
        attribute(:parent_models) { Set.new }

        # True if this model is a root model
        attr_predicate :root?, true

        # @!attribute [rw] name
        #
        # Sets a name on this model
        #
        # Only use this on 'anonymous models', i.e. on models that are not
        # meant to be assigned on a Ruby constant
        #
        # @return [String] the assigned name
        def name=(name)
            def self.name
                if @name then @name
                else super
                end
            end
            @name = name
        end

        # Set or get the root model
        attr_accessor :supermodel

        # Creates a new DataServiceModel that is a submodel of +self+
        #
        # @param [String] name the submodel name. Use this option
        #   only for "anonymous" models, i.e. models that won't be
        #   registered on a Ruby constant
        # @param [Class] type (self.class) the type of the submodel
        #
        def new_submodel(name: nil, type: self.class, **submodel_options, &block)
            model = type.new
            model.extend ModelAsModule
            if name
                model.name = name.dup
            end
            model.definition_location = call_stack
            setup_submodel(model, submodel_options, &block)
            model
        end

        # Called when a new submodel has been created, on the newly created
        # submodel
        def setup_submodel(submodel, options = Hash.new, &block)
            submodel.provides self

            if block_given?
                submodel.apply_block(&block)
            end
        end

        # In the case of model-as-modules, we always deregister (regardless of
        # the fact that +self+ is permanent or not). The reason for this is that
        # the model-as-module hierarchy is much more dynamic than
        # model-as-class. Who provides what can be changed after a #clear_model
        # call.
        def clear_model
            super
            if supermodel
                supermodel.deregister_submodels([self])
            end
            @supermodel = nil
            parent_models.clear
        end

        # Called to apply a model definition block on this model
        #
        # The definition class-eval's it
        #
        # @return [void]
        def apply_block(&block)
            class_eval(&block)
        end

        # Declares that this model also provides this other given model
        def provides(model)
            include model
            if model.root?
                self.supermodel = model
            else
                self.supermodel = model.supermodel
            end
            self.supermodel.register_submodel(self)
            self.parent_models.merge(model.parent_models)
            self.parent_models << model
        end
    end
end

