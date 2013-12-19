module MetaRuby
    module GUI
        # A Qt item model that lists Ruby modules that match a given predicate
        # (given at construction time)
        class RubyConstantsItemModel < Qt::AbstractItemModel
            ModuleInfo = Struct.new :id, :name, :this, :parent, :children, :row, :types, :full_name, :keyword_string, :path
            TypeInfo   = Struct.new :name, :priority, :color

            attr_reader :predicate
            attr_reader :id_to_module
            attr_reader :filtered_out_modules
            attr_reader :type_info
            attr_accessor :title
            attr_reader :object_paths
            # @return [Set<Object>] a set of objects that should not be
            #   discovered
            attr_reader :excludes

            def initialize(type_info = Hash.new, &predicate)
                super()
                @predicate = predicate || proc { true }
                @type_info = type_info
                @title = "Model Browser"
                @excludes = [Qt].to_set

                @id_to_module = []
                @filtered_out_modules = Set.new
                @object_paths = Hash.new
            end

            def reload
                @id_to_module = []
                @filtered_out_modules = Set.new
                
                info = discover_module(Object)
                info.id = id_to_module.size
                info.name = title
                update_module_type_info(info)
                info.row = 0
                id_to_module << info

                @object_paths = Hash.new
                generate_paths(object_paths, info, "")

                emit dataChanged(Qt::ModelIndex.new, Qt::ModelIndex.new)
            end

            def generate_paths(paths, info, current)
                info.children.each do |child|
                    child_uri = current + '/' + child.name
                    paths[child.this] = child_uri
                    generate_paths(paths, child, child_uri)
                end
            end

            def update_module_type_info(info)
                types = info.types.to_set
                info.children.each do |child_info|
                    types |= child_info.types.to_set
                end
                info.types = types.to_a.sort_by do |type|
                    type_info[type].priority
                end.reverse
            end

            def discover_module(mod, stack = Array.new)
                return if excludes.include?(mod)
                stack.push mod

                children = []
                mod_info = ModuleInfo.new(nil, nil, mod, nil, children, nil, Set.new)

                is_needed = (mod.kind_of?(Class) && mod == Object) || predicate.call(mod)

                if mod.respond_to?(:constants)
                    children_modules = begin mod.constants
                                       rescue TypeError
                                           puts "cannot discover module #{mod}"
                                           []
                                       end

                    children_modules = children_modules.map do |child_name|
                        next if !mod.const_defined_here?(child_name)
                        # Ruby issues a warning when one tries to access Config
                        # (it has been deprecated in favor of RbConfig). Ignore
                        # it explicitly
                        next if mod == Object && child_name == :Config
                        child_mod = begin mod.const_get(child_name)
                                    rescue LoadError
                                        # Handle autoload errors
                                    end
                        next if !child_mod
                        next if filtered_out_modules.include?(child_mod)
                        next if stack.include?(child_mod)
                        [child_name.to_s, child_mod]
                    end.compact.sort_by(&:first)

                    children_modules.each do |child_name, child_mod|
                        if info = discover_module(child_mod, stack)
                            info.id = id_to_module.size
                            info.name = child_name.to_s
                            info.parent = mod_info
                            info.row = children.size
                            children << info
                            id_to_module << info
                        else
                            filtered_out_modules << child_mod
                        end
                    end
                end

                if is_needed
                    klass = if mod.respond_to?(:ancestors) then mod
                            else mod.class
                            end

                    current_priority = nil
                    klass.ancestors.each do |ancestor|
                        if info = type_info[ancestor]
                            current_priority ||= info.priority
                            if current_priority < info.priority
                                mod_info.types.clear
                                mod_info.types << ancestor
                                current_priority = info.priority
                            elsif current_priority == info.priority
                                mod_info.types << ancestor
                            end
                        end
                    end
                end

                update_module_type_info(mod_info)

                if !children.empty? || is_needed
                    mod_info
                end
            ensure stack.pop
            end

            def headerData(section, orientation, role)
                if role == Qt::DisplayRole && section == 0
                    Qt::Variant.new(title)
                else Qt::Variant.new
                end
            end

            def compute_full_name(info)
                if name = info.full_name
                    return name
                else
                    full_name = []
                    current = info
                    while current.parent
                        full_name << current.name
                        current = current.parent
                    end
                    info.full_name = full_name.reverse
                end
            end

            def compute_path(info)
                if path = info.path
                    return path
                else
                    full_name = compute_full_name(info)
                    info.path = ("/" + full_name.map(&:downcase).join("/"))
                end
            end

            def compute_keyword_string(info)
                if keywords = info.keyword_string
                    return keywords
                else
                    types = info.types.map do |type|
                        type_info[type].name
                    end.sort.join(",")
                    paths = [compute_path(info)]
                    paths.concat info.children.map { |child| compute_path(child) }
                    info.keyword_string = "#{types};#{paths.join(",")}"
                end
            end

            def data(index, role)
                if info = info_from_index(index)
                    if role == Qt::DisplayRole
                        return Qt::Variant.new(info.name)
                    elsif role == Qt::EditRole
                        return Qt::Variant.new(compute_full_name(info).join("/"))
                    elsif role == Qt::UserRole
                        return Qt::Variant.new(compute_keyword_string(info))
                    end
                end
                return Qt::Variant.new
            end

            def index(row, column, parent)
                if info = info_from_index(parent)
                    if child_info = info.children[row]
                        return create_index(row, column, child_info.id)
                    end
                end
                Qt::ModelIndex.new
            end

            def parent(child)
                if info = info_from_index(child)
                    if info.parent
                        return create_index(info.parent.row, 0, info.parent.id)
                    end
                end
                Qt::ModelIndex.new
            end

            def rowCount(parent)
                if info = info_from_index(parent)
                    info.children.size
                else 0
                end
            end

            def columnCount(parent)
                return 1
            end

            def info_from_index(index)
                if !index.valid?
                    return id_to_module.last
                else
                    id_to_module[index.internal_id >> 1]
                end
            end

            def find_index_by_model(model)
                if info = id_to_module.find { |info| info.this == model }
                    return create_index(info.row, 0, info.id)
                end
            end

            def find_index_by_path(*path)
                current = id_to_module.last
                path.each do |name|
                    current = id_to_module.find do |info|
                        info.name == name && info.parent == current
                    end
                    return if !current
                end
                create_index(current.row, 0, current.id)
            end
        end
    end
end

