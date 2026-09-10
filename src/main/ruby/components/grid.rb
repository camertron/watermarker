module Watermarker
  module Components
    class Grid < Component
      attr_reader :columns

      def initialize(columns:)
        @columns = columns
      end

      def items
        @items ||= []
      end

      def with_item(&block)
        items << block
      end

      def margin_width=(width)
        @layout.marginWidth = width
      end

      def margin_height=(height)
        @layout.marginHeight = height
      end

      def set_background(*args)
        @composite.setBackground(*args)
      end

      def get_background
        @composite.getBackground
      end

      def set_layout_data(*args)
        @composite.setLayoutData(*args)
      end

      def set_location(*args)
        @composite.setLocation(*args)
      end

      def set_size(*args)
        @composite.setSize(*args)
      end

      def render_in(shell, parent)
        @composite = SWT::Composite.new(parent, SWT::Base.NONE)
        @layout = SWT::GridLayout.new(columns, false)
        @composite.setLayout(@layout)
        yield self if block_given?
        items.each { |item| item.call(@composite) }
      end
    end
  end
end
