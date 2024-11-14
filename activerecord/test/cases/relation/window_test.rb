# frozen_string_literal: true

require "cases/helper"
require "models/event"
require "models/attendee"

module ActiveRecord
  class WindowTest < ActiveRecord::TestCase
    fixtures :events, :attendees

    def test_row_number
      assert_equal [
        [1, "Alice", 15, 1],
        [1, "Bob", 15, 2],
        [1, "Charlie", 20, 3],
        [2, "David", 25, 1],
        [2, "Eve", 25, 2],
        [3, "Grace", 10, 1],
        [3, "Frank", 10, 2],
        [3, "Hannah", 15, 3]
      ], Attendee.window(
        row_number: { partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_rank
      assert_equal [
        [1, "Alice", 15, 1],
        [1, "Bob", 15, 1],
        [1, "Charlie", 20, 3],
        [2, "David", 25, 1],
        [2, "Eve", 25, 1],
        [3, "Grace", 10, 1],
        [3, "Frank", 10, 1],
        [3, "Hannah", 15, 3]
      ], Attendee.window(
        rank: { partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_dense_rank
      assert_equal [
        [1, "Alice", 15, 1],
        [1, "Bob", 15, 1],
        [1, "Charlie", 20, 2],
        [2, "David", 25, 1],
        [2, "Eve", 25, 1],
        [3, "Grace", 10, 1],
        [3, "Frank", 10, 1],
        [3, "Hannah", 15, 2]
      ], Attendee.window(
        dense_rank: { partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_percent_rank
      assert_equal [
        [1, "Alice", 15, 0.0],
        [1, "Bob", 15, 0.0],
        [1, "Charlie", 20, 1.0],
        [2, "David", 25, 0.0],
        [2, "Eve", 25, 0.0],
        [3, "Grace", 10, 0.0],
        [3, "Frank", 10, 0.0],
        [3, "Hannah", 15, 1.0]
      ], Attendee.window(
        percent_rank: { partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_lead
      assert_equal [
        [1, "Alice", 15, "Bob"],
        [1, "Bob", 15, "Charlie"],
        [1, "Charlie", 20, nil],
        [2, "David", 25, "Eve"],
        [2, "Eve", 25, nil],
        [3, "Grace", 10, "Frank"],
        [3, "Frank", 10, "Hannah"],
        [3, "Hannah", 15, nil]
      ], Attendee.window(
        lead: { value: :name, partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_first_value
      assert_equal [
        [1, "Alice", 15, "Alice"],
        [1, "Bob", 15, "Alice"],
        [1, "Charlie", 20, "Alice"],
        [2, "David", 25, "David"],
        [2, "Eve", 25, "David"],
        [3, "Grace", 10, "Grace"],
        [3, "Frank", 10, "Grace"],
        [3, "Hannah", 15, "Grace"]
      ], Attendee.window(
        first_value: { value: :name, partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_last_value
      assert_equal [
        [1, "Alice", 15, "Alice"],
        [1, "Bob", 15, "Alice"],
        [1, "Charlie", 20, "Alice"],
        [2, "David", 25, "David"],
        [2, "Eve", 25, "David"],
        [3, "Grace", 10, "Grace"],
        [3, "Frank", 10, "Grace"],
        [3, "Hannah", 15, "Grace"]
      ], Attendee.window(
        first_value: { value: :name, partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_avg
      assert_equal [
        [1, "Charlie", 20, 16.666666666666668],
        [1, "Alice", 15, 16.666666666666668],
        [1, "Bob", 15, 16.666666666666668],
        [2, "David", 25, 25.0],
        [2, "Eve", 25, 25.0],
        [3, "Hannah", 15, 11.666666666666666],
        [3, "Grace", 10, 11.666666666666666],
        [3, "Frank", 10, 11.666666666666666]
      ], Attendee.window(
        avg: { value: :ticket_price, partition: :event_id }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_sum
      assert_equal [
        [1, "Charlie", 20, 50],
        [1, "Alice", 15, 50],
        [1, "Bob", 15, 50],
        [2, "David", 25, 50],
        [2, "Eve", 25, 50],
        [3, "Hannah", 15, 35],
        [3, "Grace", 10, 35],
        [3, "Frank", 10, 35]
      ], Attendee.window(
        sum: { value: :ticket_price, partition: :event_id }
      ).pluck(:event_id, :name, :ticket_price)
    end

    # TODO: ADD MORE FUNTIONS
    def test_function_with_no_options
      assert_equal [
        ["Charlie", 1],
        ["David", 2],
        ["Hannah", 3],
        ["Alice", 4],
        ["Bob", 5],
        ["Eve", 6],
        ["Grace", 7],
        ["Frank", 8]
      ], Attendee.window(:row_number).pluck(:name)
    end

    def test_function_with_alias
      assert_equal [
        ["Charlie", 1],
        ["David", 2],
        ["Hannah", 3],
        ["Alice", 4],
        ["Bob", 5],
        ["Eve", 6],
        ["Grace", 7],
        ["Frank", 8]
      ], Attendee.window(row_number: { as: "rating" }).map { |a| [a.name, a.rating] }
    end

    def test_function_with_partition_only
      assert_equal [
        [1, "Charlie", 1],
        [1, "Alice", 2],
        [1, "Bob", 3],
        [2, "David", 1],
        [2, "Eve", 2],
        [3, "Hannah", 1],
        [3, "Grace", 2],
        [3, "Frank", 3]
      ], Attendee.window(row_number: { partition: :event_id }).pluck(:event_id, :name)
    end

    def test_function_with_order_only
      assert_equal [
        ["Grace", 10, 1],
        ["Frank", 10, 2],
        ["Hannah", 15, 3],
        ["Alice", 15, 4],
        ["Bob", 15, 5],
        ["Charlie", 20, 6],
        ["David", 25, 7],
        ["Eve", 25, 8]
      ], Attendee.window(row_number: { order: :ticket_price }).pluck(:name, :ticket_price)
    end

    def test_combined_functions
      assert_equal [
        [1, "Alice", 15, 1, 1],
        [1, "Bob", 15, 2, 1],
        [1, "Charlie", 20, 3, 3],
        [2, "David", 25, 1, 1],
        [2, "Eve", 25, 2, 1],
        [3, "Grace", 10, 1, 1],
        [3, "Frank", 10, 2, 1],
        [3, "Hannah", 15, 3, 3]
      ], Attendee.window(
        row_number: { partition: :event_id, order: :ticket_price },
        rank: { partition: :event_id, order: :ticket_price }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_works_with_select_from
      assert_equal [
        [1, "Charlie", 1],
        [2, "David", 1],
        [3, "Hannah", 1]
      ], Attendee.select(Arel.star).from(
        Attendee.window(row_number: { partition: :event_id })
      ).where("row_number = 1").pluck(:event_id, :name, :row_number)
    end

    def test_accepts_arel_arrays
      assert_equal [
        [1, "Charlie", 2],
        [2, "David", 2],
        [3, "Hannah", 2],
        [1, "Alice", 2],
        [1, "Bob", 2],
        [2, "Eve", 2],
        [3, "Grace", 2],
        [3, "Frank", 2]
      ], Attendee.window(
        nth_value: { value: [:event_id, 2] }
      ).pluck(:event_id, :name)
    end

    def test_function_partition_and_order_on_association
      assert_equal [
        ["Music Festival", "David", 1],
        ["Music Festival", "Eve", 2],
        ["Startup Meetup", "Hannah", 1],
        ["Startup Meetup", "Grace", 2],
        ["Startup Meetup", "Frank", 3],
        ["Tech Conference", "Charlie", 1],
        ["Tech Conference", "Alice", 2],
        ["Tech Conference", "Bob", 3]
      ], Attendee.joins(:event).window(
        row_number: { partition: "events.title", order: { "events.title": :asc } }
      ).pluck(:"events.title", :name)
    end

    def test_array_partition
      assert_equal [
        [1, "Alice", 15, 1],
        [1, "Bob", 15, 2],
        [1, "Charlie", 20, 1],
        [2, "David", 25, 1],
        [2, "Eve", 25, 2],
        [3, "Grace", 10, 1],
        [3, "Frank", 10, 2],
        [3, "Hannah", 15, 1]
      ], Attendee.window(
        row_number: { partition: [:event_id, :ticket_price] }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_array_order
      assert_equal [
        [1, "Alice", 15, 1],
        [1, "Bob", 15, 2],
        [1, "Charlie", 20, 3],
        [2, "David", 25, 4],
        [2, "Eve", 25, 5],
        [3, "Grace", 10, 6],
        [3, "Frank", 10, 7],
        [3, "Hannah", 15, 8]
      ], Attendee.window(
        row_number: { order: [:event_id, :ticket_price] }
      ).pluck(:event_id, :name, :ticket_price)
    end

    def test_arel_argument
      assert_equal [
        ["Bob", 1],
        ["Eve", 2],
        ["David", 1],
        ["Alice", 2],
        ["Grace", 3],
        ["Frank", 4],
        ["Hannah", 1],
        ["Charlie", 1]
      ], Attendee.window(
        row_number: { partition: Arel.sql("length(name)") }
      ).pluck(:name)
    end
  end
end
