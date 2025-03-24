module MetaRuby
    module GUI
        module HTML
            # Representation of a button in {Page}
            class Button
                # The button ID
                #
                # It is used to generate the button's {#base_url}
                #
                # @return [String]
                attr_reader :id

                # The text when the button is ON
                #
                # @return [String]
                attr_reader :on_text

                # The text when the button is OFF
                #
                # @return [String]
                attr_reader :off_text

                # The current button state
                attr_accessor :state

                # Create a button
                #
                # @param [String] id the button {#id}
                # @param [String] text the button text for a non-toggling button
                # @param [String] on_text the button text for a toggling button
                #   when it is ON
                # @param [String] off_text the button text for a toggling button
                #   when it is OFF
                # @param [Boolean] state the initial button state
                def initialize(id, text: nil, on_text: "#{id} (on)",
                    off_text: "#{id} (off)", state: false)
                    if id[0, 1] != "/"
                        id = "/#{id}"
                    elsif id[-1, 1] == "/"
                        id = id[0..-2]
                    end
                    @id = id
                    if text
                        @on_text = text
                        @off_text = text
                        @state = true
                    else
                        @on_text = on_text
                        @off_text = off_text
                        @state = state
                    end
                end

                # @api private
                #
                # The ID, quoted for HTML
                #
                # @return [String]
                def html_id
                    id.gsub(/[^\w]/, "_")
                end

                # The button base URL
                #
                # @return [String]
                def base_url
                    "btn://metaruby#{id}"
                end

                # The URL that would toggle the button (i.e. turn it off if it
                # is ON)
                def toggle_url
                    if state then "#{base_url}#off"
                    else
                        "#{base_url}#on"
                    end
                end

                # The URL that represents this button and its current state
                def url
                    if state then "#{base_url}#on"
                    else
                        "#{base_url}#off"
                    end
                end

                # The button text
                def text
                    if state then off_text
                    else
                        on_text
                    end
                end

                # Render the button as HTML
                #
                # @return [String]
                def render
                    "<a id=\"#{html_id}\" href=\"#{toggle_url}\">#{text}</a>"
                end
            end

            # Render a button bar into HTML
            #
            # @param [Array<Button>] buttons
            # @return [String]
            def self.render_button_bar(buttons)
                return if buttons.empty?

                "<div class=\"button_bar\"><span>#{buttons.map(&:render).join(' / ')}</span></div>"
            end
        end
    end
end
