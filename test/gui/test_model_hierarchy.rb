require "Qt4"
require 'metaruby/test'
require 'metaruby/gui/model_hierarchy'

module MetaRuby
    module GUI
        describe ModelHierarchy do
            before do
                if !$qApp
                    Qt::Application.new([])
                end

                @models = (0...5).map { |i| flexmock(excluded: false) }
                @root   = flexmock
                @resolver_class = Class.new do
                    def initialize(root, models)
                        @root, @models = root, models
                    end

                    def each_submodel(model)
                        if model == @root
                            @models.each { |m| yield(m, m.excluded) }
                        end
                    end

                    def split_name(model)
                        if model == @root
                            ['Root']
                        else
                            i = @models.index(model)
                            if i.even?
                                ['Even', i.to_s]
                            else
                                ['Odd', i.to_s]
                            end
                        end
                    end
                end

                @resolver = @resolver_class.new(@root, @models)
                @model_hierarchy = ModelHierarchy.new
                @model_hierarchy.add_root(@root, 0, categories: ['Test', 'Other'], resolver: @resolver)
                @model_hierarchy.reload
            end

            it "fills Qt's standard item model with the model info" do
                assert_equal 3, @model_hierarchy.row_count
                root_items = (0...3).map { |i| @model_hierarchy.take_item(i) }
                assert_equal Set['Even', 'Odd', 'Root'], root_items.map(&:text).to_set
                root      = root_items.find { |i| i.text == 'Root' }
                assert_equal 0, root.row_count
                even_root = root_items.find { |i| i.text == 'Even' }
                assert_equal 3, even_root.row_count
                odd_root  = root_items.find { |i| i.text == 'Odd' }
                assert_equal 2, odd_root.row_count
            end

            it "handles something that looks like a namespace but is actually a model" do
                even = flexmock(excluded: false)
                @models << even
                flexmock(@resolver).should_receive(:split_name).with(even).and_return(['Even'])
                flexmock(@resolver).should_receive(:split_name).pass_thru
                @model_hierarchy.reload
                even_root = @model_hierarchy.find_items("Even").first
                assert_equal even, @model_hierarchy.find_model_from_item(even_root)
                assert 3, even_root.row_count
            end

            it "fills the UserInfo with search data" do
                even_root = @model_hierarchy.find_items("Even").first
                assert_equal ",Test,Other,;,Even,;,0,2,4,", even_root.data(Qt::UserRole).to_string
                item0 = even_root.child(0)
                assert_equal ",Test,Other,;,Even,;,0,", item0.data(Qt::UserRole).to_string
            end

            it "does not include excluded models" do
                @models << flexmock(excluded: true)
                @model_hierarchy.reload
                odd_root = @model_hierarchy.find_items("Odd").first
                assert_nil odd_root.child(2)
            end
            it "does not process in following resolvers models excluded by previous resolvers" do
                @models << flexmock(excluded: true)
                new_root = flexmock
                new_resolver = Class.new(@resolver_class) do
                    def each_submodel(model)
                        if model == @root
                            @models.each { |m| yield(m, false) }
                        end
                    end
                end.new(new_root, @models)
                @model_hierarchy.add_root(@root, -1, categories: [], resolver: new_resolver)
                @model_hierarchy.reload
                odd_root = @model_hierarchy.find_items("Odd").first
                assert_nil odd_root.child(2)
            end

            describe "#find_model_from_index" do
                it "returns the model that matches a ModelIndex" do
                    even_root = @model_hierarchy.find_items("Even").first
                    item0 = even_root.child(0)
                    assert_equal @models[0],
                        @model_hierarchy.find_model_from_index(item0.index)
                end
                it "returns nil if no model matches" do
                    assert_nil @model_hierarchy.find_model_from_index(Qt::ModelIndex.new)
                end
            end

            describe "#find_item_by_path" do
                it "returns the items that matches the path" do
                    even_root = @model_hierarchy.find_items("Even").first
                    item0 = even_root.child(0)
                    assert_equal even_root, @model_hierarchy.find_item_by_path('Even')
                    assert_equal item0, @model_hierarchy.find_item_by_path('Even', '0')
                end
                it "returns nil if the root does not exist" do
                    assert_nil @model_hierarchy.find_item_by_path('DoesNotExist')
                end
                it "returns nil if a specified child does not exist" do
                    assert_nil @model_hierarchy.find_item_by_path('Even', '1')
                end
            end

            describe "#find_index_by_path" do
                it "returns the ModelIndex that matches the path" do
                    even_root = @model_hierarchy.find_items("Even").first
                    item0 = even_root.child(0)
                    assert_equal even_root.index, @model_hierarchy.find_index_by_path('Even')
                    assert_equal item0.index, @model_hierarchy.find_index_by_path('Even', '0')
                end
                it "returns nil if the root does not exist" do
                    assert_nil @model_hierarchy.find_index_by_path('DoesNotExist')
                end
                it "returns nil if a specified child does not exist" do
                    assert_nil @model_hierarchy.find_index_by_path('Even', '1')
                end
            end

            describe "#find_item_by_model" do
                it "returns the items that matches the path" do
                    even_root = @model_hierarchy.find_items("Even").first
                    item0 = even_root.child(0)
                    assert_equal item0, @model_hierarchy.find_item_by_model(@models[0])
                end
                it "returns nil if the model is not registered" do
                    assert_nil @model_hierarchy.find_item_by_model(Object.new)
                end
            end

            describe "#find_index_by_model" do
                it "returns the ModelIndex that matches the model" do
                    even_root = @model_hierarchy.find_items("Even").first
                    item0 = even_root.child(0)
                    assert_equal item0.index, @model_hierarchy.find_index_by_model(@models[0])
                end
                it "returns nil if the model is not registered" do
                    assert_nil @model_hierarchy.find_index_by_model(Object.new)
                end
            end
        end
    end
end



