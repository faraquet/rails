# frozen_string_literal: true

require "cases/helper"
require "models/essay"
require "models/post"
require "models/comment"

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
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

    def test_window_function_on_association
      assert_equal [
        ["Welcome to the weblog", "Thank you again for the welcome", 1],
        ["Welcome to the weblog", "Thank you for the welcome", 2],
        ["So I was thinking", "Don't think too hard", 1],
        ["sti comments", "Normal type", 1],
        ["sti comments", "Special type", 2],
        ["sti comments", "Special type 2", 3],
        ["sti comments", "Sub special comment", 4],
        ["sti comments", "Very Special type", 5],
        ["sti me", "Normal type", 1],
        ["sti me", "Special Type", 2],
        ["sti me", "afrase", 3],
        ["eager loading with OR'd conditions", "go wild", 1]
      ],
        Comment.joins(:post).window(
          row_number: { partition: "posts.id", order: { body: :asc }, as: "rating" }
        ).map { |p| [p.post.title, p.body, p.rating] }
    end

    def window_creates_window_function_with_partition_and_order
      relation = Post.all
      result = relation.window(partition: :author_id, order: :created_at)
      assert_equal "WINDOW w AS (PARTITION BY author_id ORDER BY created_at)", result.to_sql
    end

    def window_creates_window_function_with_alias
      relation = Post.all
      result = relation.window(rank: { partition: :author_id, order: :created_at, as: :rank })
      assert_equal "WINDOW rank AS (PARTITION BY author_id ORDER BY created_at)", result.to_sql
    end

    def window_creates_window_function_with_value
      relation = Post.all
      result = relation.window(rank: { value: :id, partition: :author_id, order: :created_at })
      assert_equal "WINDOW rank AS (PARTITION BY author_id ORDER BY created_at)", result.to_sql
    end

    def window_creates_window_function_without_partition_or_order
      relation = Post.all
      result = relation.window(rank: { value: :id })
      assert_equal "WINDOW rank AS ()", result.to_sql
    end

    def window_raises_error_for_invalid_window_value
      relation = Post.all
      assert_raises(ArgumentError) do
        relation.window(rank: { value: 123 })
      end
    end

    
  end
end
