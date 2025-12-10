# frozen_string_literal: true

class Hit::HitView < ApplicationView
  def view_template
    h1 { 'Hit hit' }
    p { 'Find me in app/views/hit/hit_view.rb' }
  end
end
