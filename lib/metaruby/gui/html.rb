require 'kramdown'
require 'metaruby/gui/html/button'
require 'metaruby/gui/html/page'
require 'metaruby/gui/html/collection'

module MetaRuby
    module GUI
        # Basic functionality to generate HTML pages
        #
        # The core functionality is in {Page}
        module HTML
            # Escape the string to include in HTML
            #
            # @param [String] string
            # @return [String]
            def self.escape_html(string)
                string.
                    gsub('<', '&lt;').
                    gsub('>', '&gt;')
            end
        end
    end
end

