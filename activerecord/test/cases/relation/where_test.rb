# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/binary"
require "models/cake_designer"
require "models/car"
require "models/category"
require "models/categorization"
require "models/chef"
require "models/post"
require "models/comment"
require "models/edge"
require "models/essay"
require "models/price_estimate"
require "models/topic"
require "models/treasure"
require "models/vertex"
require "models/cpk"
require "support/stubs/strong_parameters"

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :authors, :author_addresses, :categories, :categorizations, :cars, :treasures, :price_estimates,
      :binaries, :edges, :essays, :posts, :comments, :topics

    def test_type_casting_nested_joins
      comment = comments(:eager_other_comment1)
      assert_equal [comment], Comment.joins(post: :author).where(authors: { id: "2-foo" })
    end

    def test_where_with_through_association
      assert_equal [authors(:david)], Author.joins(:comments).where(comments: comments(:greetings))
      assert_equal [authors(:bob)], Author.joins(:categories).where(categories: categories(:technology))
    end

    def test_type_cast_is_not_evaluated_at_relation_build_time
      posts = nil

      assert_not_called_on_instance_of(Type::Value, :cast) do
        posts = Post.where(id: "1-foo")
      end
      assert_equal [posts(:welcome)], posts.to_a

      assert_not_called_on_instance_of(Type::Value, :cast) do
        posts = Post.where(id: ["1-foo", "bar"])
      end
      assert_equal [posts(:welcome)], posts.to_a
    end

    def test_where_copies_bind_params
      author = authors(:david)
      posts  = author.posts.where("posts.id != 1")
      joined = Post.where(id: posts)

      assert_operator joined.length, :>, 0

      joined.each { |post|
        assert_equal author, post.author
        assert_not_equal 1, post.id
      }
    end

    def test_where_copies_bind_params_in_the_right_order
      author = authors(:david)
      posts = author.posts.where.not(id: 1)
      joined = Post.where(id: posts, title: posts.first.title)

      assert_equal joined, [posts.first]
    end

    def test_where_copies_arel_bind_params
      chef = Chef.create!
      CakeDesigner.create!(chef: chef)

      cake_designers = CakeDesigner.joins(:chef).where(chefs: { id: chef.id })
      chefs = Chef.where(employable: cake_designers)

      assert_equal [chef], chefs.to_a
    end

    def test_where_with_invalid_value
      topics(:first).update!(parent_id: 0, written_on: nil, bonus_time: nil, last_read: nil)
      assert_empty Topic.where(parent_id: Object.new)
      assert_empty Topic.where(parent_id: "not-a-number")
      assert_empty Topic.where(written_on: "")
      assert_empty Topic.where(bonus_time: "")
      assert_empty Topic.where(last_read: "")
    end

    def test_rewhere_on_root
      assert_equal posts(:welcome), Post.rewhere(title: "Welcome to the weblog").first
    end

    def test_where_with_tuple_syntax
      first_topic = topics(:first)
      third_topic = topics(:third)

      key = [:title, :author_name]

      conditions = [
        [first_topic.title, first_topic.author_name],
        [third_topic.title, third_topic.author_name],
      ]

      assert_equal [first_topic], Topic.where([:id] => [[first_topic.id]])
      assert_equal [first_topic, third_topic].sort, Topic.where(key => conditions).sort
    end

    def test_where_with_tuple_syntax_on_composite_models
      book_one = Cpk::Book.create!(id: [1, 2])
      book_two = Cpk::Book.create!(id: [3, 4])

      assert_equal [book_one], Cpk::Book.where([:author_id, :id] => [[1, 2]])
      assert_equal [book_one, book_two].sort, Cpk::Book.where(Cpk::Book.primary_key => [[1, 2], [3, 4]]).sort
      assert_empty Cpk::Book.where([:author_id, :id] => [[1, 4], [3, 2]])
    end

    def test_where_with_tuple_syntax_with_incorrect_arity
      error = assert_raise ArgumentError do
        Cpk::Book.where([:one, :two, :three] => [1, 2, 3])
      end

      assert_match(/Expected corresponding value for.*to be an Array/, error.message)

      error = assert_raise ArgumentError do
        Cpk::Book.where([:one, :two] => 1)
      end

      assert_match(/Expected corresponding value for.*to be an Array/, error.message)
    end

    def test_where_with_tuple_syntax_and_regular_syntax_combined
      book_one = Cpk::Book.create!(id: [1, 2], title: "The Alchemist")
      book_two = Cpk::Book.create!(id: [3, 4], title: "The Alchemist")

      assert_equal [book_one, book_two].sort, Cpk::Book.where(title: "The Alchemist").sort
      assert_equal [book_one, book_two].sort, Cpk::Book.where(title: "The Alchemist", [:author_id, :id] => [[1, 2], [3, 4]]).sort
      assert_equal [book_two], Cpk::Book.where(title: "The Alchemist", [:author_id, :id] => [[3, 4]])
    end

    def test_with_tuple_syntax_and_large_values_list
      # sqlite3 raises "Expression tree is too large (maximum depth 1000)"
      skip if current_adapter?(:SQLite3Adapter)

      assert_nothing_raised do
        ids = [[1, 2]] * 1500
        Cpk::Book.where([:author_id, :id] => ids).to_sql
      end
    end

    def test_belongs_to_shallow_where
      author = Author.new
      author.id = 1

      assert_equal Post.where(author_id: 1).to_sql, Post.where(author: author).to_sql
    end

    def test_belongs_to_nil_where
      assert_equal Post.where(author_id: nil).to_sql, Post.where(author: nil).to_sql
    end

    def test_belongs_to_array_value_where
      assert_equal Post.where(author_id: [1, 2]).to_sql, Post.where(author: [1, 2]).to_sql
    end

    def test_belongs_to_nested_relation_where
      expected = Post.where(author_id: Author.where(id: [1, 2])).to_sql
      actual   = Post.where(author:    Author.where(id: [1, 2])).to_sql

      assert_equal expected, actual
    end

    def test_belongs_to_nested_where
      parent = Comment.new
      parent.id = 1

      expected = Post.where(comments: { parent_id: 1 }).joins(:comments)
      actual   = Post.where(comments: { parent: parent }).joins(:comments)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_belongs_to_nested_where_with_relation
      author = authors(:david)

      expected = Author.where(id: author).joins(:posts)
      actual   = Author.where(posts: { author_id: Author.where(id: author.id) }).joins(:posts)

      assert_equal expected.to_a, actual.to_a
    end

    def test_polymorphic_shallow_where
      treasure = Treasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_where_not_polymorphic_association
      sapphire = treasures(:sapphire)

      all = [treasures(:diamond), sapphire, cars(:honda), sapphire]
      assert_equal all, PriceEstimate.all.sort_by(&:id).map(&:estimate_of)

      actual = PriceEstimate.where.not(estimate_of: sapphire)
      only = PriceEstimate.where(estimate_of: sapphire)

      expected = all - [sapphire]
      assert_equal expected, actual.sort_by(&:id).map(&:estimate_of)
      assert_equal all - expected, only.sort_by(&:id).map(&:estimate_of)
    end

    def test_where_not_polymorphic_id_and_type_as_nand
      sapphire = treasures(:sapphire)

      all = [treasures(:diamond), sapphire, cars(:honda), sapphire]
      assert_equal all, PriceEstimate.all.sort_by(&:id).map(&:estimate_of)

      actual = PriceEstimate.where.not(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)
      only = PriceEstimate.where(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)

      expected = all - [sapphire]
      assert_equal expected, actual.sort_by(&:id).map(&:estimate_of)
      assert_equal all - expected, only.sort_by(&:id).map(&:estimate_of)
    end

    def test_where_not_association_as_nand
      sapphire = treasures(:sapphire)
      treasure = Treasure.create!(name: "my_treasure")
      PriceEstimate.create!(estimate_of: treasure, price: 2, currency: "USD")

      expected = [treasures(:diamond), sapphire, sapphire]
      actual = Treasure.joins(:price_estimates).where.not(price_estimates: { price: 2, currency: "USD" })

      assert_equal expected.sort_by(&:id), actual.sort_by(&:id)
    end

    def test_polymorphic_nested_array_where
      treasure = Treasure.new
      treasure.id = 1
      hidden = HiddenTreasure.new
      hidden.id = 2

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: [treasure, hidden])
      actual   = PriceEstimate.where(estimate_of: [treasure, hidden])

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_array_where_not
      treasure = treasures(:diamond)
      car = cars(:honda)

      expected = [price_estimates(:sapphire_1), price_estimates(:sapphire_2)]
      actual   = PriceEstimate.where.not(estimate_of: [treasure, car])

      assert_equal expected.sort_by(&:id), actual.sort_by(&:id)
    end

    def test_polymorphic_array_where_multiple_types
      treasure_1 = treasures(:diamond)
      treasure_2 = treasures(:sapphire)
      car = cars(:honda)

      expected = [price_estimates(:diamond), price_estimates(:sapphire_1), price_estimates(:sapphire_2), price_estimates(:honda)].sort
      actual = PriceEstimate.where(estimate_of: [treasure_1, treasure_2, car]).to_a.sort

      assert_equal expected, actual
    end

    def test_polymorphic_nested_relation_where
      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: Treasure.where(id: [1, 2]))
      actual   = PriceEstimate.where(estimate_of: Treasure.where(id: [1, 2]))

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_shallow_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_where
      thing = Post.new
      thing.id = 1

      expected = Treasure.where(price_estimates: { thing_type: "Post", thing_id: 1 }).joins(:price_estimates)
      actual   = Treasure.where(price_estimates: { thing: thing }).joins(:price_estimates)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_nested_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = Treasure.where(price_estimates: { estimate_of_type: "Treasure", estimate_of_id: 1 }).joins(:price_estimates)
      actual   = Treasure.where(price_estimates: { estimate_of: treasure }).joins(:price_estimates)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_decorated_polymorphic_where
      treasure_decorator = Struct.new(:model) do
        def self.method_missing(method, *args, &block)
          Treasure.send(method, *args, &block)
        end

        def is_a?(klass)
          model.is_a?(klass)
        end

        def method_missing(...)
          model.send(...)
        end
      end

      treasure = Treasure.new
      treasure.id = 1
      decorated_treasure = treasure_decorator.new(treasure)

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: decorated_treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_aliased_attribute
      expected = Topic.where(heading: "The First Topic")
      actual   = Topic.where(title: "The First Topic")

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_where_error
      assert_nothing_raised do
        Post.where(id: { "posts.author_id" => 10 }).first
      end
    end

    def test_where_with_table_name
      post = Post.first
      assert_equal post, Post.where(posts: { "id" => post.id }).first
    end

    def test_where_with_table_name_and_empty_hash
      assert_equal 0, Post.where(posts: {}).count
    end

    def test_where_with_table_name_and_empty_array
      assert_equal 0, Post.where(id: []).count
    end

    def test_where_with_empty_hash_and_no_foreign_key
      assert_equal 0, Edge.where(sink: {}).count
    end

    def test_where_with_blank_conditions
      [[], {}, nil, ""].each do |blank|
        assert_equal 4, Edge.where(blank).order("sink_id").to_a.size
      end
    end

    def test_where_with_integer_for_string_column
      count = Post.where(title: 0).count
      assert_equal 0, count
    end

    def test_where_with_float_for_string_column
      count = Post.where(title: 0.0).count
      assert_equal 0, count
    end

    def test_where_with_boolean_for_string_column
      count = Post.where(title: false).count
      assert_equal 0, count
    end

    def test_where_with_decimal_for_string_column
      count = Post.where(title: BigDecimal(0)).count
      assert_equal 0, count
    end

    def test_where_with_rational_for_string_column
      count = Post.where(title: Rational(0)).count
      assert_equal 0, count
    end

    def test_where_with_duration_for_string_column
      count = Post.where(title: 0.seconds).count
      assert_equal 0, count
    end

    def test_where_with_integer_for_binary_column
      count = Binary.where(data: 0).count
      assert_equal 0, count
    end

    def test_where_with_emoji_for_binary_column
      Binary.create!(data: "🥦")
      assert Binary.where(data: ["🥦", "🍦"]).to_sql.include?("f09fa5a6")
      assert Binary.where(data: ["🥦", "🍦"]).to_sql.include?("f09f8da6")
    end

    def test_where_on_association_with_custom_primary_key
      author = authors(:david)
      essay = Essay.where(writer: author).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_custom_primary_key_with_relation
      author = authors(:david)
      essay = Essay.where(writer: Author.where(id: author.id)).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_relation_performs_subselect_not_two_queries
      author = authors(:david)

      assert_queries_count(1) do
        Essay.where(writer: Author.where(id: author.id)).to_a
      end
    end

    def test_where_on_association_with_custom_primary_key_with_array_of_base
      author = authors(:david)
      essay = Essay.where(writer: [author]).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_custom_primary_key_with_array_of_ids
      essay = Essay.where(writer: ["David"]).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_with_relation_on_has_many_association
      essay = essays(:david_modest_proposal)
      author = Author.where(essays: Essay.where(id: essay.id)).first

      assert_equal authors(:david), author
    end

    def test_where_with_relation_on_has_one_association
      author = authors(:david)
      author_address = AuthorAddress.where(author: Author.where(id: author.id)).first
      assert_equal author_addresses(:david_address), author_address
    end

    def test_where_on_association_with_select_relation
      essay = Essay.where(author: Author.where(name: "David").select(:name)).take
      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_collection_polymorphic_relation
      treasures = Treasure.where(name: ["diamond", "emerald"], price_estimates: PriceEstimate.all)
      assert_equal [treasures(:diamond)], treasures
    end

    def test_where_with_strong_parameters
      author = authors(:david)
      params = ProtectedParams.new(name: author.name)
      assert_raises(ActiveModel::ForbiddenAttributesError) { Author.where(params) }
      assert_equal author, Author.where(params.permit!).first
    end

    def test_where_with_large_number
      assert_equal [authors(:bob)], Author.where(id: [3, 9223372036854775808])
      assert_equal [authors(:bob)], Author.where(id: 3..9223372036854775808)
    end

    def test_to_sql_with_large_number
      assert_equal [authors(:bob)], Author.find_by_sql(Author.where(id: [3, 9223372036854775808]).to_sql)
      assert_equal [authors(:bob)], Author.find_by_sql(Author.where(id: 3..9223372036854775808).to_sql)
    end

    def test_where_with_unsupported_arguments
      assert_raises(ArgumentError) { Author.where(42) }
    end

    def test_invert_where
      author = authors(:david)
      posts = author.posts.where.not(id: 1)

      assert_equal 1, posts.invert_where.first.id
    end

    def test_nested_conditional_on_enum
      post = Post.first
      Comment.create!(label: :default, post: post, body: "Nice weather today")
      assert_equal [post], Post.joins(:comments).where(comments: { label: :default, body: "Nice weather today" }).to_a
    end

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
  end
end
