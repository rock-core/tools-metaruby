require 'facets/kernel/call_stack'
module MetaRuby
    module DSLs
        # Looks for the documentation block for the element that is being built.
        #
        # @param [#===] file_match an object (typically a regular expression)
        #   that matches the file name in which the DSL is being used
        # @param [#===,nil] trigger_method an object (typically a regular expression)
        #   that matches the name of the method that initiates the creation of
        #   the element whose documentation we are looking for.
        # @return [String,nil] the parsed documentation, or nil if there is no
        #   documentation
        def self.parse_documentation_block(file_match, trigger_method = nil)
            matched_method = !trigger_method
            call_stack.each do |call|
                if matched_method && (file_match === call[0])
                    return parse_documentation_block_at(call[0], call[1])
                end
                if trigger_method
                    if trigger_method === call[2]
                        matched_method = true
                    elsif call[2] != :method_missing
                        matched_method = false
                    end
                end
            end
            nil
        end

        # Parses upwards a Ruby documentation block whose last line starts at or
        # just before the given line in the given file
        #
        # @param [String] file
        # @param [Integer] line
        # @return [String,nil] the parsed documentation, or nil if there is no
        #   documentation
        def self.parse_documentation_block_at(file, line)
            lines = File.readlines(file)

            block = []
            # Lines are given 1-based (as all editors work that way), and we
            # want the line before the definition. Remove two
            line = line - 2
            while true
                case l = lines[line]
                when /^\s*$/
                when /^\s*#/
                    block << l
                else break
                end
                line = line - 1
            end
            block = block.map do |l|
                l.strip.gsub(/^\s*#/, '')
            end
            # Now remove the same amount of spaces in front of each lines
            space_count = block.map do |l|
                l =~ /^(\s*)/
                if $1.size != l.size
                    $1.size
                end
            end.compact.min
            block = block.map do |l|
                l[space_count..-1]
            end
            if !block.empty?
                block.reverse.join("\n")
            end
        end
    end
end
