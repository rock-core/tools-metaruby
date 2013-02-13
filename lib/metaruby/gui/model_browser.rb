module MetaRuby
    module GUI
        # Widget that allows to browse the currently available models and
        # display information about them
        class ModelBrowser < Qt::Widget
            # Visualization and selection of models in the Ruby constant
            # hierarchy
            attr_reader :model_selector
            attr_reader :exception_view
            attr_reader :available_renderers
            attr_reader :display
            attr_reader :page
            attr_reader :btn_reload_models
            attr_reader :current_renderer

            attr_reader :registered_exceptions

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

            def register_type(type, rendering_class, name, priority = 0)
                model_selector.register_type(type, name, priority)
                render = rendering_class.new(page)
                available_renderers[type] = render
                connect(render, SIGNAL('updated()'), self, SLOT('update_exceptions()'))
            end

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

            def render_model(mod)
                page.object_uris = model_selector.object_paths
                model, render = available_renderers.find do |model, render|
                    mod.kind_of?(model) || (mod.kind_of?(Class) && model.kind_of?(Class) && mod <= model)
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

            def register_exception(e)
                @registered_exceptions << e
                update_exceptions
            end

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
