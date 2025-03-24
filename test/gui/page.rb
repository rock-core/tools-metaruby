#! /usr/bin/env ruby

require "metaruby"
require "metaruby/gui"

app = Qt::Application.new(ARGV)

view = Qt::WebView.new
page = MetaRuby::GUI::HTML::Page.new(view.page)
rendering = MetaRuby::GUI::ExceptionRendering.new(page)
rendering.user_file_filter = ->(file) { file =~ /user/ }
page.enable_exception_rendering(rendering)
view.resize(500, 500)
view.show

view.page.settings.setAttribute(Qt::WebSettings::DeveloperExtrasEnabled, true)
inspector = Qt::WebInspector.new
inspector.page = view.page
inspector.show

e = RuntimeError.exception("message")
e.set_backtrace %w[framework2 userline1 userline2 framework1 userline3]
page.push_exception(nil, e)

app.exec
