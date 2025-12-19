# frozen_string_literal: true

# Ensure phlex-markdown works with Phlex 2 by providing `view_template` and
# keeping a `template` alias for backwards compatibility.
if defined?(Phlex::Markdown)
  Phlex::Markdown.class_eval do
    unless instance_methods(false).include?(:view_template) && method_defined?(:view_template)
      define_method(:view_template) { |*args, **kwargs, &block| template(*args, **kwargs, &block) }
    end

    unless instance_methods(false).include?(:template) && method_defined?(:template)
      alias_method :template, :view_template
    end
  end
end
