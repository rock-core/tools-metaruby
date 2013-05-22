module MetaRuby
    # Extend in classes that are used to represent models
    #
    # @example
    #   class MyBaseClass
    #     extend MetaRuby::ModelAsClass
    #   end
    #
    # Alternatively, you can create a module that describes the metamodel and
    # extend the base model class with it
    #
    # @example
    #   module MyBaseMetamodel
    #     include MetaRuby::ModelAsModule
    #   end
    #   class MyBaseModel
    #     extend MyBaseMetamodel
    #   end
    #
    module ModelAsClass
        include Attributes
        include Registration
        extend Attributes

        # The call stack at the point of definition of this model
        attr_accessor :definition_location

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

        # The model next in the ancestry chain, or nil if +self+ is root
        #
        # @return [Class]
        def supermodel
            if superclass.respond_to?(:supermodel)
                return superclass
            end
        end

        # Creates a new submodel of +self+
        #
        # @option options [String] name forcefully set a name on the new
        #   model. Use this only for models that are not meant to be
        #   assigned on a Ruby constant
        #
        # @return [Module] a subclass of self
        def new_submodel(options = Hash.new, &block)
            options = Kernel.validate_options options,
                :name => nil

            model = self.class.new(self)
            model.permanent_model = false
            if options[:name]
                model.name = options[:name]
            end
            setup_submodel(model, &block)
            model
        end

        # Called to apply a DSL block on this model
        def apply_block(&block)
            class_eval(&block)
        end

        # Called at the end of the definition of a new submodel
        def setup_submodel(submodel, &block)
            register_submodel(submodel)

            # Note: we do not have to call #register_submodel manually here,
            # The inherited hook does that for us
            if block_given?
                submodel.apply_block(&block)
            end
        end

        # Registers submodels when a subclass is created
        def inherited(subclass)
            subclass.definition_location = call_stack
            super
            subclass.permanent_model = true
            setup_submodel(subclass)
        end

        # Call to declare that this model provides the given model-as-module
        def provides(model_as_module)
            include model_as_module
        end
    end
end

