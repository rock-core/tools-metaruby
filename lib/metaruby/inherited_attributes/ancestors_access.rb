# frozen_string_literal: true

module MetaRuby
    module InheritedAttributes
        ANCESTORS_ACCESS =
            if RUBY_VERSION < "2.1.0"
                <<-EOCODE
                ancestors = self.ancestors
                if ancestors.first != self
                    ancestors.unshift self
                end
                EOCODE
            else
                <<-EOCODE
                ancestors = self.ancestors
                EOCODE
            end
    end
end
