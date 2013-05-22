module MetaRuby
    module GUI
        # Widget that allows to browse the currently available models and
        # display information about them
        #
        # It contains a model selection widget, which lists all available models
        # and allows to select them, and a visualization pane in which the
        # corresponding model visualizations are rendered as HTML
        #
        # The object display itself is delegated to rendering objects. These
        # objects must respond to:
        #
        #   #enable: enable this renderer. This is called so that the rendering
        #     object listens to relevant Qt signals if it has e.g. the ability to
        #     interact with the user through HTML buttons
        #   #disable: disables this renderer. This is called so that the rendering
        #     object can stop listening to relevant Qt signals if it has e.g. the ability to
        #     interact with the user through HTML buttons
        #   #clear: clear existing data
        #   #render(model): render the given model
        #
        class ModelBrowser < Qt::Widget
            # @return [ModelSelector] the widget that lists available models and
            #   allows to select them
            attr_reader :model_selector
            # @return [Page] the page object that handles compositing the
            #   results of different rendering objects, as well as the ability
            #   to e.g. handle buttons
            attr_reader :page
            # @return [{Model=>Object}] set of rendering objects that are
            #   declared. The Model is a class or module that represents the
            #   set of models that the renderer can handle.
            #
            #   Do not modify directly, use {#register_type} instead
            attr_reader :available_renderers
            # @return [Qt::WebView] the HTML view widget
            attr_reader :display
            # @return [ExceptionView] view that allows to display errors to the
            #   user
            attr_reader :exception_view
            # @return the currently active renderer
            attr_reader :current_renderer
            # @return [Array<Exception>] the set of exceptions that should be
            #   displayed in {#exception_view}
            attr_reader :registered_exceptions
            # @return [Qt::PushButton] button that causes model reloading
            attr_reader :btn_reload_models

            def initialize(main = nil)
                super

                main_layout = Qt::VBoxLayout.new(self)

                menu_layout = Qt::HBoxLayout.new
                main_layout.add_layout(menu_layout)
                central_layout = Qt::HBoxLayout.new
                main_layout.add_layout(central_layout, 3)
                splitter = Qt::Splitter.new(self)
                central_layout.add_widget(splitter)
                @exception_view = ExceptionView.new
                main_layout.add_widget(exception_view, 1)

                @available_renderers = Hash.new
                @registered_exceptions = Array.new

                @btn_reload_models = Qt::PushButton.new("Reload", self)
                menu_layout.add_widget(btn_reload_models)
                menu_layout.add_stretch(1)
                update_exceptions

                add_central_widgets(splitter)
            end

            # Registers a certain kind of model as well as the information
            # needed to display it
            #
            # It registers the given type on the model browser so that it gets
            # displayed there.
            #
            # @param [Model] type the base model class for the models that are
            #   considered here
            # @param [Class] rendering_class a class from which a relevant
            #   rendering object can be created. The generated instances must
            #   follow the rules described in the documentation of
            #   {ModelBrowser}
            # @param [String] name the name that should be used for this
            #   category
            # @param [Integer] priority the priority of this category. Some
            #   models might be submodels of various types at the same time (as
            #   e.g. when both a model and its supermodel are registered here).
            #   The one with the highest priority will be used.
            def register_type(type, rendering_class, name, priority = 0)
                model_selector.register_type(type, name, priority)
                render = rendering_class.new(page)
                available_renderers[type] = render
                connect(render, SIGNAL('updated()'), self, SLOT('update_exceptions()'))
            end

            # Sets up the widgets that form the central part of the browser
            def add_central_widgets(splitter)
                @model_selector = ModelSelector.new
                splitter.add_widget(model_selector)

                # Create a central stacked layout
                @display = Qt::WebView.new
                splitter.add_widget(display)
                splitter.set_stretch_factor(1, 2)
                self.page = HTML::Page.new(display)

                model_selector.connect(SIGNAL('model_selected(QVariant)')) do |mod|
                    mod = mod.to_ruby
                    render_model(mod)
                end
            end

            # Sets the page object that should be used for rendering
            #
            # @param [Page] page the new page object
            def page=(page)
                page.connect(SIGNAL('linkClicked(const QUrl&)')) do |url|
                    if url.scheme == "link"
                        path = url.path
                        select_by_path(*path.split('/')[1..-1])
                    end
                end
                connect(page, SIGNAL('updated()'), self, SLOT('update_exceptions()'))
                @page = page
            end

            # Call to render the given model
            #
            # @param [Model] mod the model that should be rendered
            # @raises [ArgumentError] if there is no view available for the
            #   given model
            def render_model(mod)
                page.object_uris = model_selector.object_paths
                model, render = available_renderers.find do |model, render|
                    mod.kind_of?(model) || (mod.kind_of?(Module) && model.kind_of?(Module) && mod <= model)
                end
                if model
                    title = "#{mod.name} (#{model.name})"
                    begin
                        current_renderer.disable if current_renderer
                        page.clear
                        page.title = title
                        render.clear
                        render.enable
                        render.render(mod)
                        @current_renderer = render
                    rescue ::Exception => e
                        register_exception(e)
                    end
                else
                    Kernel.raise ArgumentError, "no view available for #{mod.class} (#{mod})"
                end
            end

            # Add an exception to be rendered on {#exception_view}
            def register_exception(e)
                @registered_exceptions << e
                update_exceptions
            end

            # Updates {#exception_view} from the set of registered exceptions
            def update_exceptions
                exception_view.exceptions = registered_exceptions
            end
            slots 'update_exceptions()'

            # (see ModelSelector#select_by_module)
            def select_by_path(*path)
                model_selector.select_by_path(*path)
            end

            # (see ModelSelector#select_by_module)
            def select_by_module(model)
                model_selector.select_by_module(model)
            end

            # (see ModelSelector#current_selection)
            def current_selection
                model_selector.current_selection
            end
        end
    end
end
