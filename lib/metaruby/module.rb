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

        def self.validate_constant_name(name)
            if name !~ /^[A-Z]\w+/
                raise ArgumentError, "#{name} is not a valid model name"
            end
        end

        # Common method that can be used to create and register a
        # submodel-as-a-module on a provided namespace
        #
        # It is usually used to create specific DSL-like methods that allow to
        # create these models
        def self.create_and_register_submodel(namespace, name, base_model, *args, &block)
            Models.validate_model_name(name)

            if namespace.const_defined_here?(name)
                model = namespace.const_get(name)
                if block_given?
                    model.apply_block(&block)
                end
            else 
                mod.const_set(name, model = base_model.new_submodel(*args, &block))
                model.permanent_model = true
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
            options = Kernel.validate_options options,
                :name => nil, :type => self.class

            model = options[:type].new
            model.extend ModelAsModule
            model.definition_location = call_stack
            register_submodel(model)

            if options[:name]
                model.name = options[:name].dup
            end
            model.provides self

            if block_given?
                model.apply_block(&block)
            end
            model.setup_submodel

            model
        end

        # Called to apply a model definition block on this model
        #
        # The definition class-eval's it
        #
        # @return [void]
        def apply_block(&block)
            class_eval(&block)
        end

        # Called when a new submodel has been created, on the newly created
        # submodel
        def setup_submodel
        end

        # Declares that this model also provides this other given model
        def provides(model)
            include model
            if model.root?
                self.supermodel = model
            else
                self.supermodel = model.supermodel
            end
            self.parent_models |= model.parent_models
            self.parent_models << model
        end
    end
end

