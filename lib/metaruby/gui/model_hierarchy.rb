module MetaRuby
    module GUI
        class ModelHierarchy < Qt::StandardItemModel
            Metadata = Struct.new :name, :search_key, :categories do
                def merge(other)
                    a, b = search_key, other.search_key.dup
                    if a.size < b.size
                        a, b = b, a
                    end
                    b.size.times do |i|
                        a[i] |= b[i]
                    end
                    self.search_key = a
                    self.categories = categories | other.categories
                end

                def to_user_role
                    categories = self.categories.to_a.join(",")
                    search_key = self.search_key.map do |level_keys|
                        level_keys.join(",")
                    end.join(",;,")
                    ",#{categories},;,#{search_key},"
                end
            end

            class Resolver
                def initialize(root_model)
                    @root_model = root_model
                end

                def split_name(model)
                    name = model.name
                    split = model.name.split('::')
                    if name.start_with?('::')
                        split[1..-1]
                    else split
                    end
                end

                def each_submodel(model)
                    if model == @root_model
                        model.each_submodel do |m|
                            yield(m, !m.name)
                        end
                    end
                end
            end

            def initialize
                super()
                @root_models = Array.new
            end

            # Find the resolver object that has been responsible for a given
            # object's discovery
            #
            # @return [Object,nil]
            def find_resolver_from_model(model)
                @resolver_from_model[model]
            end

            RootModel = Struct.new :model, :priority, :categories, :resolver

            def add_root(root_model, priority, categories: [], resolver: Resolver.new(root_model))
                @root_models << RootModel.new(root_model, priority, categories, resolver)
            end

            # Refresh the model to match the current hierarchy that starts with
            # this object's root model
            def reload
                begin_reset_model
                clear

                @items_to_models = Hash.new
                @models_to_items = Hash.new
                @names_to_item = Hash.new
                @items_metadata = Hash[self => Metadata.new([], [], Set.new)]
                @resolver_from_model = Hash.new

                seen = Set.new
                sorted_roots = @root_models.
                    sort_by(&:priority).reverse
                
                sorted_roots.each do |root_model|
                    models = discover_model_hierarchy(root_model.model, root_model.categories, root_model.resolver, seen)
                    models.each do |m|
                        @resolver_from_model[m] = root_model.resolver
                    end
                end
                
                rowCount.times do |row|
                    compute_and_store_metadata(item(row))
                end
            ensure
                end_reset_model
            end

            # Returns the model that matches the QStandardItem
            #
            # @return [Object,nil]
            def find_model_from_item(item)
                @items_to_models[item]
            end

            # Returns the model that matches the QModelIndex
            #
            # @return [Object,nil]
            def find_model_from_index(index)
                @items_to_models[
                    item_from_index(index)]
            end

            # @api private
            #
            # Compute each item's metadata and stores it in UserRole. The
            # metadata is stored as
            # "Category0|Category1;name/with/slashes/between/parts". This is
            # meant to be used in a seach/filter function.
            def compute_and_store_metadata(item)
                current = @items_metadata[item]

                item.rowCount.times do |row|
                    current.merge compute_and_store_metadata(item.child(row))
                end

                item.set_data(Qt::Variant.new(current.to_user_role), Qt::UserRole)
                current
            end

            # @api private
            #
            # Register a model in the hierarchy
            def register_model(model, model_categories, resolver)
                name = resolver.split_name(model)
                if !name || name.empty?
                    #raise ArgumentError, "cannot resolve #{model.name}"
                    puts "Cannot resolve #{model}"
                    return
                end

                context = name[0..-2].inject(self) do |item, name|
                    resolve_namespace(item, name)
                end
                if !(item = find_item_child_by_name(context, name.last))
                    item = Qt::StandardItem.new(name.last)
                    context.append_row(item)
                    (@names_to_item[context] ||= Hash.new)[name.last] = item
                end

                @items_metadata[item] = Metadata.new(name, name.map { |n| [n] }, model_categories)
                @items_to_models[item] = model
                @models_to_items[model] = item
            end

            # @api private
            def find_item_child_by_name(item, name)
                if context = @names_to_item[item]
                    context[name]
                end
            end

            # Returns the QStandardItem object that sits at the given path
            #
            # @return [Qt::StandardItem,nil]
            def find_item_by_path(*path)
                path.inject(self) do |parent_item, name|
                    return if !name
                    if names = @names_to_item[parent_item]
                        names[name]
                    end
                end
            end

            # Returns the ModelIndex object that sits at the given path
            #
            # @return [Qt::ModelIndex,nil]
            def find_index_by_path(*path)
                if item = find_item_by_path(*path)
                    item.index
                end
            end

            # Returns the QStandardItem object that represents the given model
            def find_item_by_model(model)
                @models_to_items[model]
            end

            # Returns the QModelIndex object that represents the given model
            def find_index_by_model(model)
                if item = find_item_by_model(model)
                    item.index
                end
            end

            # @api private
            #
            # Register a model and its whole submodels hierarchy
            def discover_model_hierarchy(root_model, categories, resolver, seen)
                discovered = Array.new
                queue = [root_model]
                categories = categories.to_set

                while !queue.empty?
                    m = queue.shift
                    next if seen.include?(m)
                    seen << m
                    discovered << m

                    register_model(m, categories, resolver)
                    resolver.each_submodel(m) do |model, excluded|
                        raise if model.kind_of?(String)
                        if excluded
                            seen << model
                        else
                            queue << model
                        end
                    end
                end
                discovered
            end

            # @api private
            #
            # Find or create the StandardItem that represents a root in the
            # hierarchy
            #
            # @param [String] name the name of the namespace
            # @return [Qt::StandardItem]
            def resolve_root_namespace(name)
                resolve_namespace(self, name)
            end

            # @api private
            #
            # Find or create the StandardItem that represents a namespace in the
            # hierarchy
            #
            # @param [Qt::StandardItem] parent_item the parent item
            # @param [String] name the name of the namespace
            # @return [Qt::StandardItem]
            def resolve_namespace(parent_item, name)
                if item = find_item_child_by_name(parent_item, name)
                    item
                else
                    item = Qt::StandardItem.new(name)

                    parent_name = @items_metadata[parent_item].name
                    @items_metadata[item] = Metadata.new(parent_name + [name], [], Set.new)
                    parent_item.append_row item
                    (@names_to_item[parent_item] ||= Hash.new)[name] = item
                end
            end
        end
    end
end

