require "Qt4"
require "metaruby/test"
require "metaruby/gui/model_selector"
require "metaruby/gui/model_hierarchy"

module MetaRuby
    module GUI
        describe ModelSelector do
            before do
                Qt::Application.new([]) unless $qApp

                @models = (0...5).map { |_i| flexmock }
                @root   = flexmock
                @resolver = Class.new do
                    def initialize(root, models)
                        @root = root
                        @models = models
                    end

                    def each_submodel(model, &block)
                        return unless model == @root

                        @models.each(&block)
                    end

                    def split_name(model)
                        if model == @root
                            ["Root"]
                        else
                            i = @models.index(model)
                            if i.even?
                                ["Even", i.to_s]
                            else
                                ["Odd", i.to_s]
                            end
                        end
                    end
                end.new(@root, @models)

                @model_selector = ModelSelector.new
                @model_selector.register_type(@root, "Test", categories: ["Test"],
                                                             resolver: @resolver)
                @model_selector.reload
                @filter_model  = @model_selector.model_filter
                @browser_model = @model_selector.browser_model
            end

            describe "name filter" do
                def dump_filtered_item_model(parent = Qt::ModelIndex.new, indent = "")
                    model_items_from_filter(parent).each_with_index do |(model_item, filter_index), i|
                        data = model_item.data(Qt::UserRole).to_string
                        puts "#{indent}[#{i}] #{model_item.text} #{data}"
                        dump_filtered_item_model(filter_index, indent + "  ")
                    end
                end

                def filter_row_count(parent = Qt::ModelIndex.new)
                    @filter_model.row_count(parent)
                end

                def model_items_from_filter(parent = Qt::ModelIndex.new)
                    (0...filter_row_count(parent)).map do |i|
                        model_item_from_filter_row(i, parent)
                    end
                end

                def model_item_from_filter_row(row, parent = Qt::ModelIndex.new)
                    filter_index = @filter_model.index(row, 0, parent)
                    model_index  = @filter_model.map_to_source(filter_index)
                    [@browser_model.item_from_index(model_index), filter_index]
                end

                it "selects the items by prefix" do
                    @model_selector.filter_box.text = "Ev"
                    @model_selector.update_model_filter
                    assert_equal 1, filter_row_count
                    model_items_from_filter
                    even_root, even_index = model_items_from_filter.first
                    assert_equal "Even", even_root.text
                    even_children = model_items_from_filter(even_index)
                    assert_equal(%w[0 2 4], even_children
                        .map { |item, _index| item.text })
                end

                it "accepts to select specific children items" do
                    @model_selector.filter_box.text = "Even/0"
                    @model_selector.update_model_filter
                    assert_equal 1, filter_row_count
                    model_items_from_filter
                    even_root, even_index = model_items_from_filter.first
                    assert_equal "Even", even_root.text
                    even_children = model_items_from_filter(even_index)
                    assert_equal(["0"], even_children
                        .map { |item, _index| item.text })
                end

                it "filters starting at an arbitrary place in the hierarchy" do
                    @model_selector.filter_box.text = "0"
                    @model_selector.update_model_filter
                    assert_equal 1, filter_row_count
                    model_items_from_filter
                    even_root, even_index = model_items_from_filter.first
                    assert_equal "Even", even_root.text
                    even_children = model_items_from_filter(even_index)
                    assert_equal(["0"], even_children
                        .map { |item, _index| item.text })
                end
            end
        end
    end
end
