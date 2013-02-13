require 'metaruby/gui/html/button'
require 'metaruby/gui/html/page'

module MetaRuby
    module GUI
        module HTML
            def self.escape_html(string)
                string.
                    gsub('<', '&lt;').
                    gsub('>', '&gt;')
            end
        end
    end
end

