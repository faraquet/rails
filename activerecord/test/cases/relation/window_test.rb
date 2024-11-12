# frozen_string_literal: true

require "cases/helper"
require "models/essay"
require "models/post"
require "models/comment"

module ActiveRecord
  class WindowTest < ActiveRecord::TestCase
    fixtures :essays, :comments, :posts

    def test_window_row_number
      assert_equal [["David", "Author", 1], ["Mary", "Author", 2], ["Steve", "Human", 1]],
        Essay.window(row_number: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" })
             .map { |p| [p.writer_id, p.writer_type, p.rating] }
    end

    def test_window_rank
      assert_equal [["David", "Author", 1], ["Mary", "Author", 2], ["Steve", "Human", 1]],
        Essay.window(rank: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" })
             .map { |p| [p.writer_id, p.writer_type, p.rating] }
    end

    def test_window_dense_rank
      assert_equal [["David", "Author", 1], ["Mary", "Author", 2], ["Steve", "Human", 1]],
        Essay.window(dense_rank: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" })
             .map { |p| [p.writer_id, p.writer_type, p.rating] }
    end

    def test_window_percent_rank
      assert_equal [["David", "Author", 0.0], ["Mary", "Author", 1.0], ["Steve", "Human", 0.0]],
        Essay.window(percent_rank: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" })
             .map { |p| [p.writer_id, p.writer_type, p.rating] }
    end

    def test_window_lead
      assert_equal [
        ["David", "Author", "Stay Home", "A Modest Proposal"],
        ["Mary", "Author", nil, "Stay Home"],
        ["Steve", "Human", nil, "Connecting The Dots"]
      ],
        Essay.window(lead: { value: :name, partition: :writer_type, order: { writer_id: :asc }, as: "next_essay" })
             .map { |p| [p.writer_id, p.writer_type, p.next_essay, p.name] }
    end

    def test_window_first_value
      assert_equal [
        ["David", "Author", "A Modest Proposal"],
        ["Mary", "Author", "A Modest Proposal"],
        ["Steve", "Human", "Connecting The Dots"]
      ],
        Essay.window(first_value: { value: :name, partition: :writer_type, as: "first_essay" })
             .map { |p| [p.writer_id, p.writer_type, p.first_essay] }
    end

    def test_window_last_value
      assert_equal [
        ["David", "Author", "Stay Home"],
        ["Mary", "Author", "Stay Home"],
        ["Steve", "Human", "Connecting The Dots"]],
        Essay.window(last_value: { value: :name, partition: :writer_type, as: "last_essay" })
             .map { |p| [p.writer_id, p.writer_type, p.last_essay] }
    end

    def test_window_average
      assert_equal [["David", "Author", 13.0], ["Mary", "Author", 13.0], ["Steve", "Human", 19.0]],
        Essay.window(avg: { value: Arel.sql("length(name)"), partition: :writer_type, as: "avg_writer_id" })
             .map { |p| [p.writer_id, p.writer_type, p.avg_writer_id] }
    end

    def test_window_sum
      # TODO: Add Fragments
      assert_equal [["David", "Author", 1790021451], ["Mary", "Author", 1790021451], ["Steve", "Human", 606697136]],
        Essay.window(sum: { value: :id, partition: :writer_type, as: "sum_writer_id" })
             .map { |p| [p.writer_id, p.writer_type, p.sum_writer_id] }
    end

    def test_window_function_with_no_options
      assert_equal [["Steve", "Human", 1], ["David", "Author", 2], ["Mary", "Author", 3]],
        Essay.window(:row_number)
             .map { |p| [p.writer_id, p.writer_type, p.row_number] }
    end

    def test_window_function_combine_with_no_options
      assert_equal [["Steve", "Human", 1, 1], ["David", "Author", 2, 1], ["Mary", "Author", 3, 1]],
        Essay.window(:row_number, :rank)
             .map { |p| [p.writer_id, p.writer_type, p.row_number, p.rank] }
    end

    def test_window_combined_functions
      assert_equal [["David", "Author", 1, 1], ["Mary", "Author", 2, 2], ["Steve", "Human", 1, 1]],
        Essay.window(
          row_number: { partition: :writer_type, order: { writer_id: :asc }, as: "row_number" },
          rank: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" }
        ).map { |p| [p.writer_id, p.writer_type, p.row_number, p.rating] }
    end

    def test_window_works_with_select_from
      assert_equal [["David", 1], ["Steve", 1]],
        Essay.select(:writer_id, :rating).from(Essay.window(
          row_number: { partition: :writer_type, order: { writer_id: :asc }, as: "row_number" },
          rank: { partition: :writer_type, order: { writer_id: :asc }, as: "rating" }
        )).where("rating = 1").map { |p| [p.writer_id, p.rating] }
    end

    def test_window_accepts_arel_arrays
      assert_equal [["David", "Author", 921819970], ["Mary", "Author", 921819970], ["Steve", "Human", nil]],
        Essay.window(nth_value: { value: [:id, 2], partition: :writer_type, as: "nth_value" })
             .map { |p| [p.writer_id, p.writer_type, p.nth_value] }
    end

    def test_window_function_partition_and_order_on_association
      assert_equal [
        ["Welcome to the weblog", "Thank you for the welcome", 1],
        ["Welcome to the weblog", "Thank you again for the welcome", 2],
        ["So I was thinking", "Don't think too hard", 1],
        ["sti comments", "Very Special type", 1],
        ["sti comments", "Special type", 2],
        ["sti comments", "Special type 2", 3],
        ["sti comments", "Normal type", 4],
        ["sti comments", "Sub special comment", 5],
        ["sti me", "Normal type", 1],
        ["sti me", "Special Type", 2],
        ["sti me", "afrase", 3],
        ["eager loading with OR'd conditions", "go wild", 1]
      ],
        Comment.joins(:post).window(
          row_number: { partition: "posts.id", order: { "posts.author_id": :asc }, as: "rating" }
        ).map { |p| [p.post.title, p.body, p.rating] }
    end

    def test_window_function_array_partition
      assert_equal [["David", "Author", 1], ["Mary", "Author", 1], ["Steve", "Human", 1]],
        Essay.window(rank: { partition: [:writer_type, :name], order: { writer_id: :asc }, as: "rating" })
             .map { |p| [p.writer_id, p.writer_type, p.rating] }
    end


    def test_window_creates_window_function_with_alias
      relation = Post.all
      result = relation.window(rank: { partition: :author_id, order: :created_at, as: :rank })
      assert_equal "SELECT \"posts\".*, rank() OVER (PARTITION BY author_id ORDER BY \"created_at\" ASC) AS rank FROM \"posts\"", result.to_sql
    end

    def test_window_creates_window_function_with_value
      relation = Post.all
      result = relation.window(rank: { value: :id, partition: :author_id, order: { created_at: :desc } })
      assert_equal "SELECT \"posts\".*, rank(id) OVER (PARTITION BY author_id ORDER BY \"created_at\" DESC) AS rank FROM \"posts\"", result.to_sql
    end

    def test_window_creates_window_function_without_partition_or_order
      relation = Post.all
      result = relation.window(rank: { value: :id })
      assert_equal "SELECT \"posts\".*, rank(id) OVER () AS rank FROM \"posts\"", result.to_sql
    end

    def test_window_raises_error_for_invalid_window_value
      relation = Post.all
      assert_raises(ArgumentError) do
        relation.window(rank: { value: 123 })
      end
    end

    ### TODO: Fix all under this line
    # def test_prepare_window_order_args_handles_single_argument
    #   result = prepare_window_order_args(:name)
    #   assert_equal [:name], result
    # end
    #
    # def test_prepare_window_order_args_handles_multiple_arguments
    #   result = prepare_window_order_args(:name, :created_at)
    #   assert_equal [:name, :created_at], result
    # end
    #
    # def test_prepare_window_order_args_handles_empty_arguments
    #   result = prepare_window_order_args
    #   assert_equal [], result
    # end
    #
    # def test_prepare_window_order_args_sanitizes_arguments
    #   result = prepare_window_order_args("name DESC", "created_at ASC")
    #   assert_equal ["name DESC", "created_at ASC"], result
    # end
    #
    # def test_prepare_window_order_args_preprocesses_arguments
    #   result = prepare_window_order_args(:name, "created_at DESC")
    #   assert_equal [:name, "created_at DESC"], result
    # end
    #
    # def test_prepare_window_order_args_handles_multiple_arguments2
    #   result = prepare_window_order_args(name: :asc)
    #   assert_equal [:name, :created_at], result
    # end
  end
end
