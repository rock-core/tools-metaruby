require 'utilrb/value_set'
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

        # @return [String] set or get the documentation text for this model
        inherited_single_value_attribute :doc

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
        attribute(:parent_models) { ValueSet.new }

        # True if this model is a root model
        attr_predicate :root?, true

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

        # Set the root model. See {root_model}
        attr_accessor :supermodel

        # Creates a new DataServiceModel that is a submodel of +self+
        #
        # @param [Hash] options the option hash
        # @option options [String] :name the submodel name. Use this option
        #   only for "anonymous" models, i.e. models that won't be
        #   registered on a Ruby constant
        # @option options [Class] :type (self.class) the type of the submodel
        #
        def new_submodel(options = Hash.new, &block)
            options, submodel_options = Kernel.filter_options options,
                :name => nil, :type => self.class

            model = options[:type].new
            model.extend ModelAsModule
            if options[:name]
                model.name = options[:name].dup
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
            self.parent_models |= model.parent_models
            self.parent_models << model
        end
    end
end

