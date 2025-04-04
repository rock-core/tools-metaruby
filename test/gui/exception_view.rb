#! /usr/bin/env ruby

require "metaruby"
require "metaruby/gui"

app = Qt::Application.new(ARGV)

view = MetaRuby::GUI::ExceptionView.new
view.user_file_filter = ->(file) { file =~ /user/ }
view.resize(200, 100)
view.show

e = RuntimeError.exception("message")
e.set_backtrace %w[framework2 userline1 userline2 framework1 userline3]
view.exceptions = [e]

app.exec
