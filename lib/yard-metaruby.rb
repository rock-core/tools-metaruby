require "pp"
module MetaRuby
    # Yard plugin to handle some of the metaruby DSL methods
    #
    # This is used by adding
    #
    #   --plugin metaruby
    #
    # to the .yardopts file
    module YARD
        include ::YARD

        # Handling of {Attributes#inherited_attribute}
        class InheritedAttributeHandler < YARD::Handlers::Ruby::AttributeHandler
            handles method_call(:inherited_attribute)
            namespace_only

            # Callback handled by YARD
            def process
                name = statement.parameters[0].jump(:tstring_content, :ident).source
                attr_name = if statement.parameters.size == 4
                                statement.parameters[1].jump(:tstring_content,
                                                             :ident).source
                            else
                                name
                            end
                options = statement.parameters.jump(:assoc)

                is_map = false
                if options != statement.parameters
                    key = options[0].jump(:ident).source
                    value = options[1].jump(:ident).source
                    is_map = true if key == "map" && value == "true"
                end

                key_type, value_type = nil

                object = YARD::CodeObjects::MethodObject.new(namespace, attr_name,
                                                             scope) do |o|
                    o.dynamic = true
                    o.aliases << "self_#{name}"
                end
                register(object)
                key_name ||=
                    if object.docstring.has_tag?("key_name")
                        object.docstring.tag("key_name").text
                    else
                        "key"
                    end
                return_type ||=
                    if object.docstring.has_tag?("return")
                        object.docstring.tag("return").types.first
                    elsif is_map
                        "Hash<Object,Object>"
                    else
                        "Array<Object>"
                    end
                if return_type =~ /^\w+<(.*)>$/
                    if is_map
                        key_type, value_type = ::Regexp.last_match(1).split(",")
                    else
                        value_type = ::Regexp.last_match(1)
                    end
                else
                    key_type = "Object"
                    value_type = "Object"
                end

                object = YARD::CodeObjects::MethodObject.new(namespace, "all_#{name}",
                                                             scope)
                object.dynamic = true
                register(object)
                object.docstring.replace("The union, along the class hierarchy, of all the values stored in #{name}\n@return [Array<#{value_type}>]")

                if is_map
                    object = YARD::CodeObjects::MethodObject.new(namespace,
                                                                 "find_#{name}", scope)
                    object.dynamic = true
                    register(object)
                    object.parameters << [key_name]
                    object.docstring.replace("
Looks for objects registered in #{name} under the given key, and returns the first one in the ancestor chain
(i.e. the one tha thas been registered in the most specialized class)

@return [#{value_type},nil] the found object, or nil if none is registered under that key")

                    object = YARD::CodeObjects::MethodObject.new(namespace,
                                                                 "has_#{name}?", scope)
                    object.dynamic = true
                    register(object)
                    object.parameters << [key_name]
                    object.docstring.replace("Returns true if an object is registered in #{name} anywhere in the class hierarchy\n@return [Boolean]")
                    object.signature = "def has_#{name}?(key)"

                    object = YARD::CodeObjects::MethodObject.new(namespace,
                                                                 "each_#{name}", scope)
                    object.dynamic = true
                    register(object)
                    object.parameters << [key_name, "nil"] << %w[uniq true]
                    object.docstring.replace("
@overload each_#{name}(#{key_name}, uniq = true)
  Enumerates all objects registered in #{name} under the given key
  @yield [element]
  @yieldparam [#{value_type}] element
@overload each_#{name}(nil, uniq = true)
  Enumerates all objects registered in #{name}
  @yield [#{key_name}, element]
  @yieldparam [#{key_type}] #{key_name}
  @yieldparam [#{value_type}] element
                    ")
                else
                    object = YARD::CodeObjects::MethodObject.new(namespace,
                                                                 "each_#{name}", scope)
                    object.dynamic = true
                    register(object)
                    object.docstring.replace("Enumerates all objects registered in #{name}\n@return []\n@yield [element]\n@yieldparam [#{value_type}] element")
                end

                return key_type, value_type if is_map

                value_type
            end
        end
        YARD::Tags::Library.define_tag("Key for inherited_attribute(_, :map => true)",
                                       :key_name)
    end
end
