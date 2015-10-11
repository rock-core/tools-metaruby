module MetaRuby
    module GUI
        module HTML
            class Button
                attr_reader :id
                attr_reader :on_text
                attr_reader :off_text
                attr_accessor :state

                def initialize(id, text: nil, on_text: "#{id} (on)", off_text: "#{id} (off)", state: false)
                    if id[0, 1] != '/'
                        id = "/#{id}"
                    elsif id[-1, 1] == '/'
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

                def html_id; id.gsub(/[^\w]/, '_') end

                def base_url; "btn://metaruby#{id}" end
                def toggle_url
                    if state then "#{base_url}#off"
                    else "#{base_url}#on"
                    end
                end
                def url
                    if state then "#{base_url}#on"
                    else "#{base_url}#off"
                    end
                end
                def text
                    if state then off_text
                    else on_text
                    end
                end

                def render
                    "<a id=\"#{html_id}\" href=\"#{toggle_url}\">#{text}</a>"
                end
            end

            def self.render_button_bar(buttons)
                if !buttons.empty?
                    "<div class=\"button_bar\"><span>#{buttons.map(&:render).join(" / ")}</span></div>"
                end
            end
        end
    end
end

