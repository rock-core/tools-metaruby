module MetaRuby
    module GUI
        # A Qt widget based on {RubyConstantsItemModel} to browse a set of
        # models, and display them when the user selects one
        class ModelSelector < Qt::Widget
            # A per-type matching of the type to the actio that allows to
            # filter/unfilter on this type
            #
            # @return [Hash<Module,Qt::Action>]
            attr_reader :type_filters

            # The view that shows the object hierarchy
            #
            # @return [Qt::TreeView]
            attr_reader :model_list

            # Qt model filter
            # @return [Qt::SortFilterProxyModel]
            attr_reader :model_filter

            # A mapping from a root model and the user-visible name for this
            # root
            #
            # @return [Hash<Object,String>]
            attr_reader :type_info

            # The Qt item model that represents the object hierarchy
            # @return [ModelHierarchy]
            attr_reader :browser_model

            # @return [Qt::PushButton] a button allowing to filter models by
            #   type
            attr_reader :btn_type_filter_menu
            # @return [Qt::LineEdit] the line edit widget that allows to modify
            #   the tree view filter
            attr_reader :filter_box
            # @return [Qt::Completer] auto-completion for {#filter_box}
            attr_reader :filter_completer

            # Create a new widget with an optional parent
            #
            # @param [Qt::Widget,nil] parent
            def initialize(parent = nil)
                super

                @type_info = Hash.new
                @browser_model = ModelHierarchy.new
                @type_filters = Hash.new

                layout = Qt::VBoxLayout.new(self)
                filter_button = Qt::PushButton.new('Filters', self)
                layout.add_widget(filter_button)
                @btn_type_filter_menu = Qt::Menu.new
                filter_button.menu = btn_type_filter_menu

                setup_tree_view(layout)
                setTabOrder(filter_box, filter_button)
                setTabOrder(filter_button, model_list)
            end

            # Register a new object type
            #
            # @param [Module] model_base a module or class whose all objects of
            #   this type have as superclass
            # @param [String] name the string that should be used to represent
            #   objects of this type
            # @param [Integer] priority if an object's ancestry matches multiple
            #   types, only the ones of the highest priority will be retained
            def register_type(root_model, name, priority = 0, categories: [], resolver: ModelHierarchy::Resolver.new)
                @browser_model.add_root(root_model, priority, categories: categories, resolver: resolver)
                type_info[root_model] = name
                action = Qt::Action.new(name, self)
                action.checkable = true
                action.checked = true
                type_filters[root_model] = action
                btn_type_filter_menu.add_action(action)
                connect(action, SIGNAL('triggered()')) do
                    update_model_filter
                end
            end

            # Update the view, reloading the underlying model
            def update
                reload
                update_model_filter
            end

            # (see ModelHierarchy#find_resolver_from_model)
            def find_resolver_from_model(model)
                @browser_model.find_resolver_from_model(model)
            end

            # @api private
            #
            # Update {#model_filter} to match the current filter setup
            def update_model_filter
                type_rx = type_filters.map do |model_base, act|
                    if act.checked?
                        type_info[model_base]
                    end
                end
                type_rx = type_rx.compact.join(",|,")

                model_filter.filter_role = Qt::UserRole # this contains the keywords (ancestry and/or name)
                # This workaround a problem that I did not have time to
                # investigate. Adding new characters to the filter updates the
                # browser just fine, while removing some characters does not
                #
                # This successfully resets the filter
                model_filter.filter_reg_exp = Qt::RegExp.new("")
                # The pattern has to match every element in the hierarchy. We
                # achieve this by making the suffix part optional
                name_rx = filter_box.text.downcase.gsub(/:+/, "/")
                name_rx = '[^;]*,[^,]*' + name_rx.split('/').join("[^,]*,[^;]*;[^;]*,") + '[^,]*,[^;]*'
                regexp = Qt::RegExp.new("(,#{type_rx},)[^;]*;#{name_rx}")
                regexp.case_sensitivity = Qt::CaseInsensitive
                model_filter.filter_reg_exp = regexp
                model_filter.invalidate
                auto_open
            end

            def filter_row_count(parent = Qt::ModelIndex.new)
                model_filter.row_count(parent)
            end

            def model_items_from_filter(parent = Qt::ModelIndex.new)
                (0...filter_row_count(parent)).map do |i|
                    model_item_from_filter_row(i, parent)
                end
            end

            def model_item_from_filter_row(row, parent = Qt::ModelIndex.new)
                filter_index = model_filter.index(row, 0, parent)
                model_index  = model_filter.map_to_source(filter_index)
                return browser_model.item_from_index(model_index), filter_index
            end

            def dump_filtered_item_model(parent = Qt::ModelIndex.new, indent = "")
                model_items_from_filter(parent).each_with_index do |(model_item, filter_index), i|
                    data = model_item.data(Qt::UserRole).to_string
                    puts "#{indent}[#{i}] #{model_item.text} #{data}"
                    dump_filtered_item_model(filter_index, indent + "  ")
                end
            end

            # Auto-open in the current state
            #
            # @param [Integer] threshold the method opens items whose number of
            #   children is lower than this threshold
            def auto_open(threshold = 5)
                current_level = [Qt::ModelIndex.new]
                while !current_level.empty?
                    count = current_level.inject(0) do |total, index|
                        total + model_filter.rowCount(index)
                    end
                    close_this_level = (count > threshold)
                    current_level.each do |index|
                        model_filter.rowCount(index).times.each do |row|
                            model_list.setExpanded(model_filter.index(row, 0, index), !close_this_level)
                        end
                    end
                    return if close_this_level

                    last_level, current_level = current_level, []
                    last_level.each do |index|
                        model_filter.rowCount(index).times.each do |row|
                            current_level << model_filter.index(row, 0, index)
                        end
                    end
                end
            end

            class ModelPathCompleter < Qt::Completer
                def splitPath(path)
                    path.split('/')
                end
                def pathFromIndex(index)
                    index.data(Qt::UserRole).to_string.split(";").last
                end
            end

            # @api private
            #
            # Helper method for {#select_first_item}
            def all_leaves(model, limit = nil, item = Qt::ModelIndex.new, result = [])
                if !model.hasChildren(item)
                    result << item
                    return result
                end

                row, child_item = 0, model.index(0, 0, item)
                while child_item.valid?
                    all_leaves(model, limit, child_item, result)
                    if limit && result.size == limit
                        return result
                    end
                    row += 1
                    child_item = model.index(row, 0, item)
                end
                return result
            end

            # Select the first displayed item
            def select_first_item
                if item = all_leaves(model_filter, 1).first
                    model_list.setCurrentIndex(item)
                end
            end

            # @api private
            #
            # Create and setup {#model_list}
            def setup_tree_view(layout)
                @model_list = Qt::TreeView.new(self)
                @model_filter = Qt::SortFilterProxyModel.new
                model_filter.filter_case_sensitivity = Qt::CaseInsensitive
                model_filter.filter_role = Qt::UserRole
                model_filter.dynamic_sort_filter = true
                model_filter.source_model = browser_model
                model_filter.sort(0)
                model_list.model = model_filter

                @filter_box = Qt::LineEdit.new(self)
                filter_box.connect(SIGNAL('textChanged(QString)')) do |text|
                    update_model_filter
                end
                filter_box.connect(SIGNAL('returnPressed()')) do |text|
                    select_first_item
                end
                @filter_completer = ModelPathCompleter.new(browser_model, self)
                filter_completer.case_sensitivity = Qt::CaseInsensitive
                filter_box.completer = filter_completer
                layout.add_widget(filter_box)
                layout.add_widget(model_list)

                model_list.selection_model.connect(SIGNAL('currentChanged(const QModelIndex&, const QModelIndex&)')) do |index, _|
                    index = model_filter.map_to_source(index)
                    if model = browser_model.find_model_from_index(index)
                        emit model_selected(Qt::Variant.from_ruby(model, model))
                    end
                end
            end
            signals 'model_selected(QVariant)'

            # Reload the object model, keeping the current selection if possible
            def reload
                if current_model = current_selection
                    current_path = @browser_model.find_path_from_model(current_model)
                end

                browser_model.reload
                if current_path
                    select_by_path(*current_path)
                elsif current_model
                    select_by_model(current_model)
                end
            end

            # Resets the current filter
            def reset_filter
                # If there is a filter, reset it and try again
                if !filter_box.text.empty?
                    filter_box.text = ""
                    true
                end
            end

            # Maps a model index from the source index to the filtered index,
            # e.g. to select something in the view.
            #
            # In addition to the normal map_from_source call, it allows to
            # control whether the filter should be reset if the index given as
            # parameter is currently filtered out
            #
            # @param [Qt::ModelIndex] source_index an index valid in {#browser_model}
            # @param [Boolean] reset_filter if true, the filter
            #   is reset if the requested index is currently filtered out
            # @return [Qt::ModelIndex] an index filtered by {#model_filter}
            def map_index_from_source(source_index, reset_filter: true)
                index = model_filter.map_from_source(source_index)
                if !index
                    return
                elsif !index.valid?
                    if !reset_filter
                        return index
                    end
                    self.reset_filter
                    model_filter.map_from_source(source_index)
                else index
                end
            end

            # Selects the current model given a path in the constant names
            # This emits the model_selected signal
            #
            # @return [Boolean] true if the path resolved to something known,
            #   and false otherwise
            def select_by_path(*path)
                if index = browser_model.find_index_by_path(*path)
                    index = map_index_from_source(index)
                    model_list.current_index = index
                    true
                end
            end

            # Selects the given model if it registered in the model list
            # This emits the model_selected signal
            #
            # @return [Boolean] true if the path resolved to something known,
            #   and false otherwise
            def select_by_model(model)
                if index = browser_model.find_index_by_model(model)
                    index = map_index_from_source(index)
                    model_list.current_index = index
                    true
                end
            end

            # Returns the currently selected item
            # @return [RubyModuleModel::ModuleInfo,nil] nil if there are no
            #   selections
            def current_selection
                index = model_list.selection_model.current_index
                if index.valid?
                    index = model_filter.map_to_source(index)
                    browser_model.info_from_index(index)
                end
            end

            def object_paths
                browser_model.object_paths
            end
        end
    end
end
