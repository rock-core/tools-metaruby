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
            # @return [Qt::WebView] the HTML view widget
            attr_reader :display
            # @return [ExceptionView] view that allows to display errors to the
            #   user
            attr_reader :exception_view
            # @return [Qt::PushButton] button that causes model reloading
            attr_reader :btn_reload_models
            # @return [RenderingManager] the object that manages all the
            #   rendering objects available
            attr_reader :manager
            # @return [Array<Exception>] set of exceptions raised during the
            #   last rendering step
            attr_reader :registered_exceptions
            # @return [Array<Model,[String]>] the browsing history, as either
            #   direct modules or module name path (suitable to be given to
            #   #select_by_path)
            attr_reader :history
            # @return [Integer] the index of the current link in the history
            attr_reader :history_index

            # A Page object with a #link_to method that is suitable for the
            # model browser
            class Page < HTML::Page
                def uri_for(object)
                    if (obj_name = object.name) && (obj_name =~ /^[\w:]+$/)
                        path = obj_name.split("::")
                        "/" + path.join("/")
                    else super
                    end
                end
            end


            def initialize(main = nil)
                super

                @manager = RenderingManager.new

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

                @history = Array.new
                @history_index = -1

                add_central_widgets(splitter)
                setTabOrder(model_selector, display)
                setTabOrder(display, btn_reload_models)
            end

            # Update the model selector after {register_type} got called
            def update_model_selector
                model_selector.update
            end

            # Registers a certain kind of model as well as the information
            # needed to display it
            #
            # It registers the given type on the model browser so that it gets
            # displayed there.
            #
            # You must call {update_model_selector} after this call for the
            # modification to have any effect (i.e. for the newly registered
            # models to appear on the selector)
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
                manager.register_type(type, rendering_class)
            end

            # Sets up the widgets that form the central part of the browser
            def add_central_widgets(splitter)
                @model_selector = ModelSelector.new
                splitter.add_widget(model_selector)

                # Create a central stacked layout
                display = @display = Qt::WebView.new
                browser = self
                display.singleton_class.class_eval do
                    define_method :contextMenuEvent do |event|
                        menu = Qt::Menu.new(self)
                        act = page.action(Qt::WebPage::Back)
                        act.enabled = true
                        menu.add_action act
                        connect(act, SIGNAL(:triggered), browser, SLOT(:back))
                        act = page.action(Qt::WebPage::Forward)
                        act.enabled = true
                        connect(act, SIGNAL(:triggered), browser, SLOT(:forward))
                        menu.add_action act
                        menu.popup(event.globalPos)
                        event.accept
                    end
                end
                splitter.add_widget(display)
                splitter.set_stretch_factor(1, 2)
                self.page = Page.new(display.page)

                model_selector.connect(SIGNAL('model_selected(QVariant)')) do |mod|
                    mod = mod.to_ruby
                    push_to_history(mod)
                    render_model(mod)
                end
            end

            # Sets the page object that should be used for rendering
            #
            # @param [Page] page the new page object
            def page=(page)
                manager.page = page
                page.connect(SIGNAL('linkClicked(const QUrl&)')) do |url|
                    if url.scheme == "link"
                        path = url.path
                        path = path.split('/')[1..-1]
                        select_by_path(*path)
                    end
                end
                connect(page, SIGNAL('updated()'), self, SLOT('update_exceptions()'))
                connect(manager, SIGNAL('updated()'), self, SLOT('update_exceptions()'))
                @page = page
            end

            # Call to render the given model
            #
            # @param [Model] mod the model that should be rendered
            # @raises [ArgumentError] if there is no view available for the
            #   given model
            def render_model(mod, options = Hash.new)
                page.clear
                @registered_exceptions.clear
                reference_model, _ = manager.find_renderer(mod)
                if mod
                    page.title = "#{mod.name} (#{reference_model.name})"
                    begin
                        manager.render(mod, options)
                    rescue ::Exception => e
                        @registered_exceptions << e
                    end
                else
                    @registered_exceptions << ArgumentError.new("no view available for #{mod} (#{mod.class})")
                end
                update_exceptions
            end

            # Updates {#exception_view} from the set of registered exceptions
            def update_exceptions
                exception_view.exceptions = registered_exceptions +
                    manager.registered_exceptions
            end
            slots 'update_exceptions()'

            # (see ModelSelector#select_by_module)
            def select_by_path(*path)
                if model_selector.select_by_path(*path)
                    push_to_history(path)
                end
            end

            # (see ModelSelector#select_by_module)
            def select_by_module(model)
                if model_selector.select_by_module(model)
                    push_to_history(model)
                end
            end

            # (see ModelSelector#current_selection)
            def current_selection
                model_selector.current_selection
            end

            # Pushes one element in the history
            #
            # If the history index is not at the end, the remainder is discarded
            def push_to_history(object)
                return if object == history[history_index]

                @history = history[0, history_index + 1]
                history << object
                @history_index = history.size - 1
            end

            # Go forward in the browsing history
            def forward
                return if history_index == history.size - 1
                @history_index += 1
                select_by_history_element(history[history_index])
            end

            # Go back in the browsing history
            def back
                return if history_index <= 0
                @history_index -= 1
                select_by_history_element(history[history_index])
            end

            slots :back, :forward

            # Selects a given model based on a value in the history
            def select_by_history_element(h)
                if h.respond_to?(:to_ary)
                    select_by_path(*h)
                else select_by_module(h)
                end
            end
        end
    end
end
