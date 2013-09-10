module MetaRuby
    module DSLs
        def self.find_through_method_missing(object, m, args, *suffixes)
            m = m.to_s
            suffixes.each do |s|
                find_method_name = "find_#{s}"
                if m == find_method_name
                    raise NoMethodError.new("#{object} has no method called #{find_method_name}", m)
                elsif m =~ /(.*)_#{s}$/
                    name = $1
                    if found = object.send(find_method_name, name)
                        if !args.empty?
                            raise ArgumentError, "expected zero arguments to #{m}, got #{args.size}", caller(4)
                        else return found
                        end
                    else
                        msg = "#{self} has no #{s} named #{name}"
                        raise NoMethodError.new(msg, m), msg, caller(4)
                    end
                end
            end
            nil
        end
    end
end
