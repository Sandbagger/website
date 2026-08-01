# frozen_string_literal: true

require "test_helper"

class Writing::PublicationClockTest < ActiveSupport::TestCase
  test "uses the next Brussels date at summer midnight" do
    clock = Writing::PublicationClock.new

    assert_equal Date.new(2026, 7, 31), clock.today(at: Time.utc(2026, 7, 31, 21, 59, 59))
    assert_equal Date.new(2026, 8, 1), clock.today(at: Time.utc(2026, 7, 31, 22, 0))
  end

  test "uses the next Brussels date at winter midnight" do
    clock = Writing::PublicationClock.new

    assert_equal Date.new(2026, 1, 1), clock.today(at: Time.utc(2026, 1, 1, 22, 59, 59))
    assert_equal Date.new(2026, 1, 2), clock.today(at: Time.utc(2026, 1, 1, 23, 0))
  end

  test "uses Brussels daylight saving time" do
    clock = Writing::PublicationClock.new

    assert_equal Date.new(2026, 3, 29), clock.today(at: Time.utc(2026, 3, 29, 21, 59, 59))
    assert_equal Date.new(2026, 3, 30), clock.today(at: Time.utc(2026, 3, 29, 22, 0))
  end
end
