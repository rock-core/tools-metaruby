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
            return unless name !~ /^[A-Z]\w+$/

            raise ArgumentError, "#{name} is not a valid model name"
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
        def self.create_and_register_submodel(
            namespace, name, base_model, *args, **kw, &block
        )
            ModelAsModule.validate_constant_name(name)

            if namespace.const_defined?(name, false)
                model = namespace.const_get(name)
                base_model.setup_submodel(model, *args, **kw, &block)
            else
                model = base_model.new_submodel(*args, **kw, &block)
                namespace.const_set(name, model)
                model.permanent_model = if namespace.respond_to?(:permanent_model?)
                                            namespace.permanent_model?
                                        else
                                            Registration.accessible_by_name?(namespace)
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
            @name = name
        end

        def name
            @name || super
        end

        def self.extend_object(obj)
            obj.instance_variable_set :@name, nil
            super
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
            model.name = name.dup if name
            model.definition_location =
                if MetaRuby.keep_definition_location?
                    caller_locations
                else
                    []
                end
            setup_submodel(model, **submodel_options, &block)
            model
        end

        # Called when a new submodel has been created, on the newly created
        # submodel
        def setup_submodel(submodel, **, &block)
            submodel.provides self
            submodel.apply_block(&block) if block_given?
        end

        # In the case of model-as-modules, we always deregister (regardless of
        # the fact that +self+ is permanent or not). The reason for this is that
        # the model-as-module hierarchy is much more dynamic than
        # model-as-class. Who provides what can be changed after a #clear_model
        # call.
        def clear_model
            super
            supermodel.deregister_submodels([self]) if supermodel
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

        # Tests whether self provides the given model
        #
        # @param [Module] model
        def provides?(model)
            self <= model
        end

        # Declares that this model also provides this other given model
        def provides(model)
            include model

            model_root =
                if model.root? then model
                else
                    model.supermodel
                end

            if !supermodel
                self.supermodel = model_root
                supermodel.register_submodel(self)
            elsif supermodel != model_root
                if model_root.provides?(supermodel)
                    self.supermodel = model_root
                elsif !supermodel.provides?(model_root)
                    raise ArgumentError,
                          "#{model}'s root is #{model_root} while #{self} is #{supermodel}, which are unrelated"
                end
                supermodel.register_submodel(self)
            end

            parent_models.merge(model.parent_models)
            parent_models << model
        end
    end
end
