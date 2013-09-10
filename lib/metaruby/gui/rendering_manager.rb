module MetaRuby
    module GUI
        class RenderingManager < Qt::Object
            # @return [#push] the page object on which we render
            attr_reader :page
            # @return [{Model=>Object}] set of rendering objects that are
            #   declared. The Model is a class or module that represents the
            #   set of models that the renderer can handle.
            #   It is ordered by order of priority, i.e. the first model that
            #   matches will be used.
            #   Do not modify directly, use {#register_type} instead
            attr_reader :available_renderers
            # The last used rendering objects
            attr_reader :current_renderer

            def initialize(page = nil)
                super()
                @page = page
                @available_renderers = Hash.new
            end

            def registered_exceptions
                if current_renderer.respond_to?(:registered_exceptions)
                    current_renderer.registered_exceptions
                else []
                end
            end

            # Registers a certain kind of model as well as the information
            # needed to display it
            #
            # It registers the given type on the model browser so that it gets
            # displayed there.
            #
            # @param [Class] type the base model class for the models that are
            #   considered here
            # @param [Class] rendering_class a class from which a relevant
            #   rendering object can be created. The generated instances must
            #   follow the rules described in the documentation of
            #   {ModelBrowser}
            def register_type(type, rendering_class, render_options = Hash.new)
                render = if rendering_class.kind_of?(Class)
                             rendering_class.new(page)
                         else
                             rendering_class
                         end
                available_renderers[type] = [render, render_options]
                connect(render, SIGNAL('updated()'), self, SIGNAL('updated()'))
            end

            # Changes on which page this rendering manager should act
            def page=(page)
                return if @page == page
                @page = page
                @available_renderers = available_renderers.map_value do |key, (value, render_options)|
                    new_render = value.class.new(page)
                    disconnect(value, SIGNAL('updated()'))
                    connect(new_render, SIGNAL('updated()'), self, SIGNAL('updated()'))
                    [new_render, render_options]
                end
            end

            def find_renderer(mod)
                available_renderers.find do |model, _|
                    mod.kind_of?(model) || (mod.kind_of?(Module) && model.kind_of?(Module) && mod <= model)
                end
            end

            def disable
                if current_renderer
                    current_renderer.disable
                end
            end

            def enable
                if current_renderer
                    current_renderer.enable
                end
            end

            def clear
                if current_renderer
                    current_renderer.clear
                end
            end


            # Call to render the given model
            #
            # @param [Model] mod the model that should be rendered
            # @raises [ArgumentError] if there is no view available for the
            #   given model
            def render(object, push_options = Hash.new)
                _, (renderer, render_options) = find_renderer(object)
                if renderer
                    if current_renderer
                        current_renderer.clear
                        current_renderer.disable
                    end
                    renderer.enable
                    renderer.render(object, render_options.merge(push_options))
                    @current_renderer = renderer
                else
                    Kernel.raise ArgumentError, "no view available for #{object} (#{object.class})"
                end
            end

            signals 'updated()'
        end
    end
end

