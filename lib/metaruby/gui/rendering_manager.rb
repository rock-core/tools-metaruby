module MetaRuby
    module GUI
        # Management of HTML rendering of objects of different types
        #
        # Objects of this class allow to register a set of renderers, dedicated
        # to rendering objects of a certain type (defined as a superclass) and
        # automatically switch between the rendering objects.
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
            # The rendering object used last in {#render}
            attr_reader :current_renderer

            # Create a rendering manager that acts on a given page
            def initialize(page = nil)
                super()
                @page = page
                @available_renderers = Hash.new
            end

            # A list of exceptions that happened during rendering
            #
            # @return [Array<Exception>]
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
            # @param [Class] type objects whose class or ancestry include 'type'
            #   will be rendered using the provided rendering class. If more tha
            #   none matches, the first one is used.
            # @param [Class] rendering_class a class from which a relevant
            #   rendering object can be created. The generated instances must
            #   follow the rules described in the documentation of
            #   {ModelBrowser}
            # @param [Hash] render_options a set of options that must be passed
            #   to the renderer's #render method
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

            # @api private
            #
            # Find a rendering object for the given object
            #
            # @param [Object] mod the object we need to render
            # @return [(Class,(#render,Hash)),nil] either the base class,
            #   rendering object and rendering options that should be used for
            #   the given object, or nil if there are no matching rendering
            #   objects
            def find_renderer(mod)
                available_renderers.find do |model, _|
                    mod.kind_of?(model) || (mod.kind_of?(Module) && model.kind_of?(Module) && mod <= model)
                end
            end

            # Disable the current renderer
            def disable
                if current_renderer
                    current_renderer.disable
                end
            end

            # Enable the current renderer
            def enable
                if current_renderer
                    current_renderer.enable
                end
            end

            # Clear the current renderer
            def clear
                if current_renderer
                    current_renderer.clear
                end
            end

            # Call to render the given model
            #
            # The renderer that has been used is made active (enabled) and
            # stored in {#current_renderer}. The previous one is disabled and
            # cleared.
            #
            # @param [Model] object the model that should be rendered
            # @param [Hash] push_options options that should be passed to the
            #   object's renderer {#render} method
            # @raise [ArgumentError] if there is no view available for the
            #   given model
            def render(object, **push_options)
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

