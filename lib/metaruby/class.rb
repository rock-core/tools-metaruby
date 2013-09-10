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

        # @return [String] set or get the documentation text for this model
        inherited_single_value_attribute :doc

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
        
        # This flag is used to notify {#inherited} that it is being called from
        # new_submodel, in which case it should not 
        #
        # This mechanism works as:
        #   - inherited(subclass) is called right away after class.new is called
        #     (so, we don't have to take recursive calls into account)
        #   - it is a TLS, so thread safe
        #
        FROM_NEW_SUBMODEL_TLS = :metaruby_class_new_called_from_new_submodel

        # Creates a new submodel of +self+
        #
        # @option options [String] name forcefully set a name on the new
        #   model. Use this only for models that are not meant to be
        #   assigned on a Ruby constant
        #
        # @return [Module] a subclass of self
        def new_submodel(options = Hash.new, &block)
            options, submodel_options = Kernel.filter_options options,
                :name => nil

            Thread.current[FROM_NEW_SUBMODEL_TLS] = true
            model = self.class.new(self)
            model.permanent_model = false
            if options[:name]
                model.name = options[:name]
            end
            setup_submodel(model, submodel_options, &block)
            model
        end

        # Called to apply a DSL block on this model
        def apply_block(&block)
            class_eval(&block)
        end

        # Called at the end of the definition of a new submodel
        def setup_submodel(submodel, options = Hash.new, &block)
            register_submodel(submodel)

            if block_given?
                submodel.apply_block(&block)
            end
        end

        # Registers submodels when a subclass is created
        def inherited(subclass)
            from_new_submodel = Thread.current[FROM_NEW_SUBMODEL_TLS]
            Thread.current[FROM_NEW_SUBMODEL_TLS] = false

            subclass.definition_location = call_stack
            super
            subclass.permanent_model = subclass.accessible_by_name? &&
                subclass.permanent_definition_context?
            if !from_new_submodel
                setup_submodel(subclass)
            end
        end

        # Call to declare that this model provides the given model-as-module
        def provides(model_as_module)
            include model_as_module
        end
    end
end

