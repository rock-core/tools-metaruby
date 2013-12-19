module MetaRuby
    module GUI
        # A Qt widget that allows to browse the models registered in the Ruby
        # constanat hierarchy
        class ModelSelector < Qt::Widget
            attr_reader :btn_type_filter_menu
            attr_reader :type_filters
            attr_reader :model_list
            attr_reader :model_filter
            # @return [Qt::LineEdit] the line edit widget that allows to modify
            #   the tree view filter
            attr_reader :filter_box
            # @return [Qt::Completer] auto-completion for {filter_box}
            attr_reader :filter_completer
            attr_reader :type_info
            attr_reader :browser_model

            def initialize(parent = nil)
                super

                @type_info = Hash.new
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

            def register_type(model_base, name, priority = 0)
                type_info[model_base] = RubyConstantsItemModel::TypeInfo.new(name, priority)
                action = Qt::Action.new(name, self)
                action.checkable = true
                action.checked = true
                type_filters[model_base] = action
                btn_type_filter_menu.add_action(action)
                connect(action, SIGNAL('triggered()')) do
                    update_model_filter
                end
            end

            def update
                update_model_filter
                reload
            end

            def update_model_filter
                type_rx = type_filters.map do |model_base, act|
                    if act.checked?
                        type_info[model_base].name
                    end
                end
                type_rx = type_rx.compact.join("|")

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
                model_filter.filter_reg_exp = Qt::RegExp.new("(#{type_rx}).*;.*#{name_rx}")
                auto_open
            end

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

            def model?(obj)
                type_info.any? do |model_base, _|
                    obj.kind_of?(model_base) ||
                        (obj.kind_of?(Module) && obj <= model_base)
                end
            end

            class ModelPathCompleter < Qt::Completer
                def splitPath(path)
                    path.split('/')
                end
                def pathFromIndex(index)
                    index.data(Qt::UserRole).split(";").last
                end
            end

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

            def select_first_item
                if item = all_leaves(model_filter, 1).first
                    model_list.setCurrentIndex(item)
                end
            end

            def setup_tree_view(layout)
                @model_list = Qt::TreeView.new(self)
                @model_filter = Qt::SortFilterProxyModel.new
                model_filter.filter_case_sensitivity = Qt::CaseInsensitive
                model_filter.dynamic_sort_filter = true
                model_filter.filter_role = Qt::UserRole
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
                    mod = browser_model.info_from_index(index)
                    if model?(mod.this)
                        emit model_selected(Qt::Variant.from_ruby(mod.this, mod.this))
                    end
                end
            end
            signals 'model_selected(QVariant)'

            def reload
                if current = current_selection
                    current_module = current.this
                    current_path = []
                    while current
                        current_path.unshift current.name
                        current = current.parent
                    end
                end

                @browser_model = RubyConstantsItemModel.new(type_info) do |mod|
                    model?(mod)
                end
                browser_model.reload
                model_filter.source_model = browser_model

                if current_path && !select_by_path(*current_path)
                    select_by_module(current_module)
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
            # @param [Qt::ModelIndex] an index valid in {browser_model}
            # @option options [Boolean] :reset_filter (true) if true, the filter
            #   is reset if the requested index is currently filtered out
            # @return [Qt::ModelIndex] an index filtered by {model_filter}
            def map_index_from_source(source_index, options = Hash.new)
                options = Kernel.validate_options options, :reset_filter => true
                index = model_filter.map_from_source(source_index)
                if !index
                    return
                elsif !index.valid?
                    if !options[:reset_filter]
                        return index
                    end
                    reset_filter
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
                    model_list.selection_model.set_current_index(index, Qt::ItemSelectionModel::ClearAndSelect)
                    true
                end
            end

            # Selects the given model if it registered in the model list
            # This emits the model_selected signal
            #
            # @return [Boolean] true if the path resolved to something known,
            #   and false otherwise
            def select_by_module(model)
                if index = browser_model.find_index_by_model(model)
                    index = map_index_from_source(index)
                    model_list.selection_model.set_current_index(index, Qt::ItemSelectionModel::ClearAndSelect)
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
