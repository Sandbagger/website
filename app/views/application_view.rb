# frozen_string_literal: true

class ApplicationView < ApplicationComponent
  # The ApplicationView is an abstract class for all your views.

  # By default, it inherits from `ApplicationComponent`, but you
  # can change that to `Phlex::HTML` if you want to keep views and
  # components independent.

  include Phlex::Rails::Helpers::LinkTo

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
