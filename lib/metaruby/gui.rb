require 'Qt4'
require 'qtwebkit'
require 'kramdown'
require 'pp'
require 'metaruby/gui/html'
require 'metaruby/gui/ruby_constants_item_model'
require 'metaruby/gui/rendering_manager'
require 'metaruby/gui/model_browser'
require 'metaruby/gui/model_selector'
require 'metaruby/gui/exception_view'

module MetaRuby
    # Set of widgets and classes that are used to view/browse MetaRuby-based models using Qt
    #
    # Model views are using HTML, the rendering of which is done through
    # {GUI::HTML::Page}. The main functionality centers around
    # {GUI::ModelBrowser} which allows to browse models in a hierarchy, and
    # display them in a HTML::Page.
    #
    # {GUI::ExceptionRendering} allows to render exceptions into a HTML page as
    # well, the formatting being delegated to the exception's #pretty_print
    # method.
    module GUI
    end
end
