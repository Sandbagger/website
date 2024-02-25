# frozen_string_literal: true

class ApplicationComponent < Phlex::HTML
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::LinkTo

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end

  def center
    render CenterComponent.new do
      yield
    end
  end

  def box(invert: false)
    render BoxComponent.new(invert: invert) do
      yield
    end
  end

  def stack
    render StackComponent.new do
      yield
    end
  end

  def cluster
    render ClusterComponent.new do
      yield
    end
  end
end
