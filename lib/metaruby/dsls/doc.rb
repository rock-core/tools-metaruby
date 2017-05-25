require 'facets/kernel/call_stack'
module MetaRuby
    module DSLs
        # Looks for the documentation block for the element that is being built.
        #
        # @param [#===] file_match an object (typically a regular expression)
        #   that matches the file name in which the DSL is being used
        # @param [#===] trigger_method an object (typically a regular expression)
        #   that matches the name of the method that initiates the creation of
        #   the element whose documentation we are looking for.
        # @return [String,nil] the parsed documentation, or nil if there is no
        #   documentation
        #
        # @example find the documentation block of an event creation
        #   # assuming the following toplevel DSL code in a file called test.orogen
        #   task "Task" do
        #     # Just an example event
        #     event "test"
        #   end
        #
        #   # One would use the following code to extract the documentation
        #   # above the test event declaration. The call must be made within the
        #   # event creation code
        #   MetaRuby::DSLs.parse_documentation_block(/test\.orogen$/, "event")
        #   
        def self.parse_documentation_block(file_match, trigger_method = /.*/)
            last_method_matched = false
            caller_locations(1).each do |call|
                this_method_matched =
                    if trigger_method === call.label
                        true
                    elsif call.label == 'method_missing'
                        last_method_matched
                    else
                        false
                    end

                if !this_method_matched && last_method_matched && (file_match === call.absolute_path)
                    if File.file?(call.absolute_path)
                        return parse_documentation_block_at(call.absolute_path, call.lineno)
                    else return
                    end
                end
                last_method_matched = this_method_matched
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

            space_count = nil
            while true
                l = lines[line]
                comment_match = /^\s*#/.match(l)
                if comment_match
                    comment_line  = comment_match.post_match.rstrip
                    stripped_line = comment_line.lstrip
                    leading_spaces = comment_line.size - stripped_line.size
                    if !stripped_line.empty? && (!space_count || space_count > leading_spaces)
                        space_count = leading_spaces
                    end
                    block.unshift(comment_line)
                else break
                end
                line = line - 1
            end
            if !block.empty?
                space_count ||= 0
                block.map { |l| l[space_count..-1] }.join("\n")
            end
        end
    end
end
