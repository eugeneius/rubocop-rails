# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      # Looks for uses of `each_with_object({}) { ... }`,
      # `map { ... }.to_h`, and `Hash[map { ... }]` that are transforming
      # an enumerable into a hash where the keys are the original elements.
      # Rails provides the `index_with` method for this purpose.
      #
      # @example
      #   # bad
      #   [1, 2, 3].each_with_object({}) { |el, h| h[el] = foo(el) }
      #   [1, 2, 3].to_h { |el| [el, foo(el)] }
      #   [1, 2, 3].map { |el| [el, foo(el)] }.to_h
      #   Hash[[1, 2, 3].collect { |el| [el, foo(el)] }]
      #
      #   # good
      #   [1, 2, 3].index_with { |el| foo(el) }
      #
      # Also looks for static default values and enforces passing them as
      # positional arguments instead of using a block.
      #
      # @example
      #   # bad
      #   [1, 2, 3].index_with { true }
      #   [1, 2, 3].index_with { nil }
      #   [1, 2, 3].index_with { 3 }
      #   [1, 2, 3].index_with { :foo }
      #
      #   # good
      #   [1, 2, 3].index_with(true)
      #   [1, 2, 3].index_with { [] }
      #   [1, 2, 3].index_with { foo }
      class IndexWith < Base
        extend AutoCorrector
        extend TargetRailsVersion
        include IndexMethod

        minimum_target_rails_version 6.0

        def_node_matcher :on_bad_each_with_object, <<~PATTERN
          (block
            (call _ :each_with_object (hash))
            (args (arg $_el) (arg _memo))
            (call (lvar _memo) :[]= (lvar _el) $!`_memo))
        PATTERN

        def_node_matcher :on_bad_to_h, <<~PATTERN
          {
            (block
              (call _ :to_h)
              (args (arg $_el))
              (array (lvar _el) $_))
            (numblock
              (call _ :to_h) $1
              (array (lvar :_1) $_))
          }
        PATTERN

        def_node_matcher :on_bad_map_to_h, <<~PATTERN
          (call
            {
              (block
                (call _ {:map :collect})
                (args (arg $_el))
                (array (lvar _el) $_))
              (numblock
                (call _ {:map :collect}) $1
                (array (lvar :_1) $_))
            }
            :to_h)
        PATTERN

        def_node_matcher :on_bad_hash_brackets_map, <<~PATTERN
          (send
            (const {nil? cbase} :Hash)
            :[]
            {
              (block
                (call _ {:map :collect})
                (args (arg $_el))
                (array (lvar _el) $_))
              (numblock
                (call _ {:map :collect}) $1
                (array (lvar :_1) $_))
            }
          )
        PATTERN

        DEFAULT_VALUE_MSG = 'Pass static default values to `index_with` as positional arguments.'

        def_node_matcher :on_bad_index_with, <<~PATTERN
          (block (call _ :index_with) _ {true false nil numeric sym})
        PATTERN

        def on_block(block)
          super

          on_bad_index_with(block) do
            add_offense(block, message: DEFAULT_VALUE_MSG) do |corrector|
              range = block.send_node.loc.selector.end.join(block.loc.end)
              corrector.replace(range, "(#{block.body.source})")
            end
          end
        end

        private

        def new_method_name
          'index_with'
        end
      end
    end
  end
end
