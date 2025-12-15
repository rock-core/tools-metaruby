# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Lint/NestedMethodDefinition
# rubocop:disable Naming/MethodName

module MetaRuby
    module InheritedAttributes
        module Map # rubocop:disable Metrics/ModuleLength
            def self.common_without_promotion(context, cache:)
                context.class_eval do
                    InheritedAttributes::Map.common_has_NAME(self)
                    InheritedAttributes::Map.common_initialization(context, cache: cache)

                    describe "each_NAME" do
                        it "does nothing if no values are set" do
                            assert_equal [], @leaf.each_attr.to_a
                        end

                        it "discovers the hierarchy's entries " \
                           "even if it has no entries itself" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("baz", 84)
                            klass = Class.new(@leaf)
                            assert_equal Set[["foo", 42], ["bar", 21], ["baz", 84]],
                                         klass.each_attr.to_set
                        end

                        it "enumerates the aggregated values" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("baz", 84)
                            assert_equal Set[["foo", 42], ["bar", 21], ["baz", 84]],
                                         @leaf.each_attr.to_set
                            assert_equal Set[["foo", 42], ["bar", 21]],
                                         @child.each_attr.to_set
                            assert_equal Set[["foo", 42]],
                                         @parent.each_attr.to_set
                        end

                        it "reports the value from the most derived " \
                           "if there is more than one match" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("foo", 84)
                            assert_equal Set[["foo", 84], ["bar", 21]],
                                         @leaf.each_attr.to_set
                            assert_equal Set[["foo", 42], ["bar", 21]],
                                         @child.each_attr.to_set
                            assert_equal Set[["foo", 42]],
                                         @parent.each_attr.to_set
                        end

                        def self.common(context)
                            context.before do
                                @parent.attr_set("foo", 42)
                                @child.attr_set("bar", 21)
                                @leaf.attr_set("baz", 84)
                                read_attr
                            end

                            context.it "shows values that have been updated " \
                                       "on the parent" do
                                attr_set(@child, "bar", 22)

                                assert_equal Set[["foo", 42], ["bar", 22], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 42], ["bar", 22]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42]],
                                             @parent.each_attr.to_set
                            end

                            context.it "shows values that have been updated " \
                                       "on the grandparent" do
                                attr_set(@parent, "foo", 43)

                                assert_equal Set[["foo", 43], ["bar", 21], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 43], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 43]],
                                             @parent.each_attr.to_set
                            end

                            context.it "shows values from grandparents that have been " \
                                       "superseded by new values on the parent" do
                                attr_set(@child, "foo", 22)

                                assert_equal Set[["foo", 22], ["bar", 21], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 22], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42]],
                                             @parent.each_attr.to_set
                            end

                            context.it "does not show new values from the grandparent " \
                                       "if the parent has said value" do
                                attr_set(@parent, "bar", 22)

                                assert_equal Set[["foo", 42], ["bar", 21], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 42], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42], ["bar", 22]],
                                             @parent.each_attr.to_set
                            end
                        end

                        describe "using NAME_set" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            common(self)
                        end

                        describe "using NAMES_update" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            common(self)
                        end

                        describe "key deletion" do
                            before do
                                @parent.attr_set("foo", 42)
                                @child.attr_set("bar", 21)
                                @leaf.attr_set("baz", 84)
                                read_attr
                            end

                            def self.common(context)
                                context.it "stops showing values that have been " \
                                           "removed from the parent" do
                                    attr_delete(@child, "bar")

                                    assert_equal Set[["foo", 42], ["baz", 84]],
                                                 @leaf.each_attr.to_set
                                    assert_equal Set[["foo", 42]],
                                                 @child.each_attr.to_set
                                    assert_equal Set[["foo", 42]],
                                                 @parent.each_attr.to_set
                                end

                                context.it "stops showing values that have been " \
                                           "removed from the grandparent" do
                                    attr_delete(@parent, "foo")

                                    assert_equal Set[["bar", 21], ["baz", 84]],
                                                 @leaf.each_attr.to_set
                                    assert_equal Set[["bar", 21]], @child.each_attr.to_set
                                    assert_equal Set[], @parent.each_attr.to_set
                                end

                                context.it "shows values from the grandparent if the " \
                                           "corresponding element from the parent " \
                                           "is removed" do
                                    @child.attr_set("foo", 22)
                                    read_attr

                                    attr_delete(@child, "foo")

                                    assert_equal(
                                        Set[["foo", 42], ["bar", 21], ["baz", 84]],
                                        @leaf.each_attr.to_set
                                    )
                                    assert_equal Set[["foo", 42], ["bar", 21]],
                                                 @child.each_attr.to_set
                                    assert_equal(
                                        Set[["foo", 42]], @parent.each_attr.to_set
                                    )
                                end
                            end

                            describe "using NAME_delete" do
                                def attr_delete(obj, key)
                                    obj.attr_delete(key)
                                end

                                common(self)
                            end

                            describe "using NAMES_update" do
                                def attr_delete(obj, key)
                                    obj.attrs_update do |h|
                                        h.delete(key)
                                        h
                                    end
                                end

                                common(self)
                            end
                        end

                        def read_attr
                            [@parent, @child, @leaf]
                                .permutation.first.each(&:all_attr)
                        end
                    end

                    describe "each_NAME_key" do
                        it "does nothing if no values are set" do
                            assert_equal [], @leaf.each_attr_keys.to_a
                        end

                        it "discovers the hierarchy's entries " \
                           "even if it has no entries itself" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("baz", 84)
                            klass = Class.new(@leaf)
                            assert_equal Set["foo", "bar", "baz"],
                                         klass.each_attr_keys.to_set
                        end

                        it "enumerates the aggregated values" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("baz", 84)
                            assert_equal Set["foo", "bar", "baz"],
                                         @leaf.each_attr_keys.to_set
                            assert_equal Set["foo", "bar"],
                                         @child.each_attr_keys.to_set
                            assert_equal Set["foo"],
                                         @parent.each_attr_keys.to_set
                        end

                        it "report only once keys that appear " \
                           "more than once in the hierarchy" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("foo", 84)
                            assert_equal %w[bar foo],
                                         @leaf.each_attr_keys.to_a.sort
                            assert_equal %w[bar foo],
                                         @child.each_attr_keys.to_a.sort
                            assert_equal ["foo"],
                                         @parent.each_attr_keys.to_a.sort
                        end

                        describe "key deletion" do
                            before do
                                @parent.attr_set("foo", 42)
                                @child.attr_set("bar", 21)
                                @leaf.attr_set("baz", 84)
                                read_attr
                            end

                            def self.common(context)
                                context.it "stops showing keys that have been " \
                                           "removed from the parent" do
                                    attr_delete(@child, "bar")

                                    assert_equal Set["foo", "baz"],
                                                 @leaf.each_attr_keys.to_set
                                    assert_equal ["foo"],
                                                 @child.each_attr_keys.to_a
                                    assert_equal ["foo"],
                                                 @parent.each_attr_keys.to_a
                                end

                                context.it "stops showing values that have been " \
                                           "removed from the grandparent" do
                                    attr_delete(@parent, "foo")

                                    assert_equal Set["bar", "baz"],
                                                 @leaf.each_attr_keys.to_set
                                    assert_equal Set["bar"], @child.each_attr_keys.to_set
                                    assert_equal Set[], @parent.each_attr_keys.to_set
                                end

                                context.it "is not affected by the removal of keys " \
                                           "from the child if the same key exists in " \
                                           "the grandparent" do
                                    @child.attr_set("foo", 22)
                                    read_attr

                                    attr_delete(@child, "foo")

                                    assert_equal(
                                        Set["foo", "bar", "baz"],
                                        @leaf.each_attr_keys.to_set
                                    )
                                    assert_equal Set["foo", "bar"],
                                                 @child.each_attr_keys.to_set
                                    assert_equal(
                                        Set["foo"], @parent.each_attr_keys.to_set
                                    )
                                end
                            end

                            describe "using NAME_delete" do
                                def attr_delete(obj, key)
                                    obj.attr_delete(key)
                                end

                                common(self)
                            end

                            describe "using NAMES_update" do
                                def attr_delete(obj, key)
                                    obj.attrs_update do |h|
                                        h.delete(key)
                                        h
                                    end
                                end

                                common(self)
                            end
                        end

                        def read_attr
                            [@parent, @child, @leaf]
                                .permutation.first.each(&:all_attr)
                        end
                    end

                    describe "find_NAME" do
                        it "returns nil if no values are set at all" do
                            assert_nil @leaf.find_attr("foo")
                        end

                        it "discovers the hierarchy's entries " \
                           "even if it has no entries itself" do
                            @parent.attr_set("foo", 42)
                            klass = Class.new(@leaf)
                            assert_equal 42, klass.find_attr("foo")
                        end

                        def self.common(context)
                            context.it "returns the value associated with a key " \
                                       "if defined at the leaf" do
                                attr_set(@leaf, "baz", 84)
                                assert_equal 84, @leaf.find_attr("baz")
                            end

                            context.it "returns the value associated with a key " \
                                       "if defined on the grandparent" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 84, @leaf.find_attr("baz")
                            end

                            context.it "returns the value from the most derived class " \
                                       "if more than one level has the same key" do
                                attr_set(@parent, "baz", 84)
                                attr_set(@child, "baz", 42)
                                assert_equal 42, @leaf.find_attr("baz")
                            end

                            context.it "returns the value from the most derived class " \
                                       "if it is added after a first read" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 84, @leaf.find_attr("baz")
                                attr_set(@child, "baz", 42)
                                assert_equal 42, @leaf.find_attr("baz")
                            end

                            context.it "returns remaining values after a delete" do
                                attr_set(@parent, "baz", 84)
                                attr_set(@child, "baz", 42)
                                assert_equal 42, @leaf.find_attr("baz")
                                attr_delete(@child, "baz")
                                assert_equal 84, @leaf.find_attr("baz")
                            end

                            context.it "returns nil if there is no associated value" do
                                assert_nil @leaf.find_attr("something")
                            end

                            context.it "returns nil if the value got deleted" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 84, @leaf.find_attr("baz")
                                attr_delete(@parent, "baz")
                                assert_nil @leaf.find_attr("something")
                            end
                        end

                        describe "using NAME_set and NAME_delete" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            def attr_delete(obj, key)
                                obj.attr_delete(key)
                            end

                            common(self)
                        end

                        describe "using NAME_set and NAME_update" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            def attr_delete(obj, key)
                                obj.attrs_update do
                                    _1.delete(key)
                                    _1
                                end
                            end
                            common(self)
                        end

                        describe "using NAME_update and NAME_delete" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            def attr_delete(obj, key)
                                obj.attr_delete(key)
                            end
                            common(self)
                        end

                        describe "using NAME_update" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            def attr_delete(obj, key)
                                obj.attrs_update do
                                    _1.delete(key)
                                    _1
                                end
                            end
                            common(self)
                        end
                    end
                end
            end

            def self.common_with_promotion(context, cache:)
                context.class_eval do
                    InheritedAttributes::Map.common_has_NAME(self)
                    InheritedAttributes::Map.common_initialization(context, cache: cache)

                    describe "each_NAME" do
                        it "does nothing if no values are set" do
                            assert_equal [], @leaf.each_attr.to_a
                        end

                        it "enumerates the aggregated values" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("baz", 84)
                            assert_equal Set[["foo", 44], ["bar", 22], ["baz", 84]],
                                         @leaf.each_attr.to_set
                            assert_equal Set[["foo", 43], ["bar", 21]],
                                         @child.each_attr.to_set
                            assert_equal Set[["foo", 42]],
                                         @parent.each_attr.to_set
                        end

                        it "reports the value from the most derived " \
                           "if there is more than one match" do
                            @parent.attr_set("foo", 42)
                            @child.attr_set("bar", 21)
                            @leaf.attr_set("foo", 84)
                            assert_equal Set[["foo", 84], ["bar", 22]],
                                         @leaf.each_attr.to_set
                            assert_equal Set[["foo", 43], ["bar", 21]],
                                         @child.each_attr.to_set
                            assert_equal Set[["foo", 42]],
                                         @parent.each_attr.to_set
                        end

                        def self.common(context)
                            context.before do
                                @parent.attr_set("foo", 42)
                                @child.attr_set("bar", 21)
                                @leaf.attr_set("baz", 84)
                                read_attr
                            end

                            context.it "shows values that have been updated " \
                                       "on the parent" do
                                @child.attr_set("bar", 22)

                                assert_equal Set[["foo", 44], ["bar", 23], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 43], ["bar", 22]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42]],
                                             @parent.each_attr.to_set
                            end

                            context.it "shows values that have been updated " \
                                       "on the grandparent" do
                                @parent.attr_set("foo", 43)

                                assert_equal Set[["foo", 45], ["bar", 22], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 44], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 43]],
                                             @parent.each_attr.to_set
                            end

                            context.it "shows values from grandparents that have been " \
                                       "superseded by new values on the parent" do
                                @child.attr_set("foo", 22)

                                assert_equal Set[["foo", 23], ["bar", 22], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 22], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42]],
                                             @parent.each_attr.to_set
                            end

                            context.it "does not show new values from the grandparent " \
                                       "if the parent has said value" do
                                @parent.attr_set("bar", 20)

                                assert_equal Set[["foo", 44], ["bar", 22], ["baz", 84]],
                                             @leaf.each_attr.to_set
                                assert_equal Set[["foo", 43], ["bar", 21]],
                                             @child.each_attr.to_set
                                assert_equal Set[["foo", 42], ["bar", 20]],
                                             @parent.each_attr.to_set
                            end
                        end

                        describe "using NAME_set" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            common(self)
                        end

                        describe "using update_NAMES" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            common(self)
                        end

                        describe "key deletion" do
                            before do
                                @parent.attr_set("foo", 42)
                                @child.attr_set("bar", 21)
                                @leaf.attr_set("baz", 84)
                                read_attr
                            end

                            def self.common(context)
                                context.it "stops showing values that have been " \
                                           "removed from the parent" do
                                    attr_delete(@child, "bar")

                                    assert_equal Set[["foo", 44], ["baz", 84]],
                                                 @leaf.each_attr.to_set
                                    assert_equal Set[["foo", 43]],
                                                 @child.each_attr.to_set
                                    assert_equal Set[["foo", 42]],
                                                 @parent.each_attr.to_set
                                end

                                context.it "stops showing values that have been " \
                                           "removed from the grandparent" do
                                    attr_delete(@parent, "foo")

                                    assert_equal Set[["bar", 22], ["baz", 84]],
                                                 @leaf.each_attr.to_set
                                    assert_equal Set[["bar", 21]], @child.each_attr.to_set
                                    assert_equal Set[], @parent.each_attr.to_set
                                end

                                context.it "shows values from the grandparent if the " \
                                           "corresponding element from the parent " \
                                           "is removed" do
                                    @child.attr_set("foo", 22)
                                    read_attr

                                    attr_delete(@child, "foo")

                                    assert_equal(
                                        Set[["foo", 44], ["bar", 22], ["baz", 84]],
                                        @leaf.each_attr.to_set
                                    )
                                    assert_equal Set[["foo", 43], ["bar", 21]],
                                                 @child.each_attr.to_set
                                    assert_equal(
                                        Set[["foo", 42]], @parent.each_attr.to_set
                                    )
                                end
                            end

                            describe "using NAME_delete" do
                                def attr_delete(obj, key)
                                    obj.attr_delete(key)
                                end

                                common(self)
                            end

                            describe "using update_NAMES" do
                                def attr_delete(obj, key)
                                    obj.attrs_update do |h|
                                        h.delete(key)
                                        h
                                    end
                                end

                                common(self)
                            end
                        end

                        def read_attr
                            [@parent, @child, @leaf]
                                .permutation.first.each(&:all_attr)
                        end
                    end

                    describe "find_NAME" do
                        it "returns nil if no values are set at all" do
                            assert_nil @leaf.find_attr("foo")
                        end

                        def self.common(context)
                            context.it "returns the value associated with a key " \
                                       "if defined at the leaf" do
                                attr_set(@leaf, "baz", 84)
                                assert_equal 84, @leaf.find_attr("baz")
                            end

                            context.it "returns the value associated with a key " \
                                       "if defined on the grandparent" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 86, @leaf.find_attr("baz")
                            end

                            context.it "returns the value from the most derived class " \
                                       "if more than one level has the same key" do
                                attr_set(@parent, "baz", 84)
                                attr_set(@child, "baz", 42)
                                assert_equal 43, @leaf.find_attr("baz")
                            end

                            context.it "returns the value from the most derived class " \
                                       "if it is added after a first read" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 86, @leaf.find_attr("baz")
                                attr_set(@child, "baz", 42)
                                assert_equal 43, @leaf.find_attr("baz")
                            end

                            context.it "returns remaining values after a delete" do
                                attr_set(@parent, "baz", 84)
                                attr_set(@child, "baz", 42)
                                assert_equal 43, @leaf.find_attr("baz")
                                attr_delete(@child, "baz")
                                assert_equal 86, @leaf.find_attr("baz")
                            end

                            context.it "returns nil if there is no associated value" do
                                assert_nil @leaf.find_attr("something")
                            end

                            context.it "returns nil if the value got deleted" do
                                attr_set(@parent, "baz", 84)
                                assert_equal 86, @leaf.find_attr("baz")
                                attr_delete(@parent, "baz")
                                assert_nil @leaf.find_attr("something")
                            end
                        end

                        describe "using NAME_set and NAME_delete" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            def attr_delete(obj, key)
                                obj.attr_delete(key)
                            end
                            common(self)
                        end

                        describe "using NAME_set and NAME_update" do
                            def attr_set(obj, key, value)
                                obj.attr_set(key, value)
                            end

                            def attr_delete(obj, key)
                                obj.attrs_update do
                                    _1.delete(key)
                                    _1
                                end
                            end
                            common(self)
                        end

                        describe "using NAME_update and NAME_delete" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            def attr_delete(obj, key)
                                obj.attr_delete(key)
                            end
                            common(self)
                        end

                        describe "using NAME_update" do
                            def attr_set(obj, key, value)
                                obj.attrs_update { _1.merge({ key => value }) }
                            end

                            def attr_delete(obj, key)
                                obj.attrs_update do
                                    _1.delete(key)
                                    _1
                                end
                            end
                            common(self)
                        end
                    end
                end
            end

            def self.common_has_NAME_internal(context)
                context.it "reports the existence of a key if defined at the leaf" do
                    attr_set(@leaf, "baz", 84)
                    assert @leaf.has_attr?("baz")
                    refute @child.has_attr?("baz")
                    refute @parent.has_attr?("baz")
                end

                context.it "reports the existence of a key if defined " \
                           "somewhere in the hierarchy" do
                    @parent.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                    assert @child.has_attr?("foo")
                    assert @parent.has_attr?("foo")
                end

                context.it "reports the existence of a key added after a first check" do
                    refute @leaf.has_attr?("foo")
                    @parent.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                end

                context.it "reports that a key that has been removed from the " \
                           "grandparent does not exist" do
                    @parent.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                    @parent.attr_delete("foo")
                    refute @leaf.has_attr?("foo")
                end

                context.it "reports that a key that has been removed from the parent " \
                           "does not exist" do
                    @child.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                    @child.attr_delete("foo")
                    refute @leaf.has_attr?("foo")
                end

                context.it "reports that a key exists, that has been removed from the " \
                           "parent but exists in the grandparent" do
                    @parent.attr_set("foo", 42)
                    @child.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                    @child.attr_delete("foo")
                    assert @leaf.has_attr?("foo")
                end

                context.it "reports that a key exists, that has been removed from the " \
                           "grandparent but exists in the parent" do
                    @parent.attr_set("foo", 42)
                    @child.attr_set("foo", 42)
                    assert @leaf.has_attr?("foo")
                    @parent.attr_delete("foo")
                    assert @leaf.has_attr?("foo")
                end
            end

            def self.common_has_NAME(context)
                context.send(:describe, "has_NAME?") do
                    it "returns false if called when no values are set at all" do
                        refute @leaf.has_attr?("foo")
                    end

                    it "discovers the hierarchy's entries " \
                       "even if it has no entries itself" do
                        @parent.attr_set("foo", 42)
                        klass = Class.new(@leaf)
                        assert klass.has_attr?("foo")
                    end

                    describe "using NAME_set and NAME_delete" do
                        def attr_set(obj, key, value)
                            obj.attr_set(key, value)
                        end

                        def attr_delete(obj, key)
                            obj.attr_delete(key)
                        end
                        InheritedAttributes::Map.common_has_NAME_internal(self)
                    end

                    describe "using NAME_set and NAME_update" do
                        def attr_set(obj, key, value)
                            obj.attr_set(key, value)
                        end

                        def attr_delete(obj, key)
                            obj.attrs_update do
                                _1.delete(key)
                                _1
                            end
                        end
                        InheritedAttributes::Map.common_has_NAME_internal(self)
                    end

                    describe "using NAME_update and NAME_delete" do
                        def attr_set(obj, key, value)
                            obj.attrs_update { _1.merge({ key => value }) }
                        end

                        def attr_delete(obj, key)
                            obj.attr_delete(key)
                        end
                        InheritedAttributes::Map.common_has_NAME_internal(self)
                    end

                    describe "using NAME_update" do
                        def attr_set(obj, key, value)
                            obj.attrs_update { _1.merge({ key => value }) }
                        end

                        def attr_delete(obj, key)
                            obj.attrs_update do
                                _1.delete(key)
                                _1
                            end
                        end
                        InheritedAttributes::Map.common_has_NAME_internal(self)
                    end
                end
            end

            def self.common_initialization(context, cache:)
                context.send(:describe, "initialization") do
                    define_method(:inherited_attribute_cache) { cache }
                    def self.common(context)
                        context.class_eval do
                            it "initializes the cache and self-values ivar" do
                                root = create_root_class
                                assert_properly_initialized(root)
                            end

                            it "initializes the cache and self-values ivar " \
                               "in subclasses" do
                                root = create_root_class
                                subclass = Class.new(root)
                                assert_properly_initialized(subclass)
                            end

                            it "initializes the cache and self-values ivar " \
                               "in the singleton class" do
                                root = create_root_class
                                obj = root.new
                                subclass = obj.singleton_class
                                assert_properly_initialized(subclass)
                            end
                        end
                    end

                    describe "direct usage" do
                        def create_root_class
                            cache = inherited_attribute_cache
                            Class.new do
                                extend ModelAsClass
                                extend Attributes

                                inherited_attribute(
                                    :attr, :attrs, map: true, cache: cache
                                ) { {} }
                            end
                        end

                        common(self)
                    end

                    describe "in the class' singleton class" do
                        def create_root_class
                            cache = inherited_attribute_cache
                            root_class = Class.new do
                                extend ModelAsClass
                                class << self
                                    extend Attributes
                                end
                            end

                            root_class.singleton_class.inherited_attribute(
                                :attr, :attrs, map: true, cache: cache
                            ) { {} }
                            root_class
                        end

                        common(self)
                    end

                    describe "in module and then extended" do
                        def create_root_class
                            cache = inherited_attribute_cache
                            mod = Module.new do
                                include ModelAsClass
                                extend Attributes

                                inherited_attribute(
                                    :attr, :attrs, map: true, cache: cache
                                ) { {} }
                            end

                            Class.new do
                                extend mod
                            end
                        end

                        common(self)
                    end

                    describe "in a module itself included " \
                             "in another before extending the class" do
                        def create_root_class
                            cache = inherited_attribute_cache
                            mod = Module.new do
                                include ModelAsClass
                                extend Attributes

                                inherited_attribute(
                                    :attr, :attrs, map: true, cache: cache
                                ) { {} }
                            end

                            final_mod = Module.new do
                                include mod
                            end

                            Class.new do
                                extend final_mod
                            end
                        end

                        common(self)
                    end

                    def assert_properly_initialized(klass)
                        assert_equal({}, klass.self_attrs)
                        assert_equal [], klass.each_attr.to_a
                    end
                end
            end
        end
    end
end

# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Lint/NestedMethodDefinition
# rubocop:enable Naming/MethodName
