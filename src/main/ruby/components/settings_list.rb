module Watermarker
  module Components
    class SettingsList < Component
      attr_reader :theme

      def initialize(theme:)
        @theme = theme
        @items = []
      end

      def render_in(shell, parent)
        @composite = SWT::Composite.new(parent, SWT::Base.NONE)

        @composite.addListener(SWT::Base.Paint, Listener.new do |e|
          e.gc.setBackground(theme.inputs_background_color)
          size = @composite.getSize
          e.gc.fillRoundRectangle(0, 0, size.x, size.y, 20, 20)
        end)

        grid_layout = SWT::GridLayout.new(2, false)
        grid_layout.horizontalSpacing = 10
        grid_layout.verticalSpacing = 10
        grid_layout.marginWidth = 10
        grid_layout.marginHeight = 10
        @composite.setLayout(grid_layout)

        yield self if block_given?

        @items.each_with_index do |(props, content_block), idx|
          render_separator_in(@composite) if idx > 0

          text_label = SWT::Label.new(@composite, SWT::Base.BORDER)
          text_label.setText(props[:label])
          text_label.setLayoutData(SWT::GridData.new(SWT::Base.BEGINNING, SWT::Base.CENTER, false, false))
          text_label.pack

          widget = content_block.call(@composite)
          grid_data = SWT::GridData.new(SWT::Base.END, SWT::Base.CENTER, true, false)
          grid_data.widthHint = props[:width] if props[:width]

          if widget.respond_to?(:set_layout_data)
            widget.set_layout_data(grid_data)
          else
            widget.setLayoutData(grid_data)
          end
        end

        @composite.pack
      end

      def with_item(label:, width: 200, &block)
        @items << [{ label: label, width: width }, block]
      end

      def set_location(*args)
        @composite.setLocation(*args)
      end

      def set_background(*args)
        @composite.setBackground(*args)
      end

      def set_size(*args)
        @composite.setSize(*args)
      end

      def get_size
        @composite.getSize
      end

      def get_location
        @composite.getLocation
      end

      private

      def render_separator_in(parent)
        separator = SWT::Canvas.new(parent, SWT::Base.DOUBLE_BUFFERED)

        separator.addListener(SWT::Base.Paint, Listener.new do |e|
          area = e.widget.getClientArea
          e.gc.setForeground(theme.inputs_separator_color)
          e.gc.drawLine(10, 0, area.width - 20, 0)
        end)

        grid_data = SWT::GridData.new(SWT::Base.FILL, SWT::Base.FILL, true, false, 2, 1)
        grid_data.heightHint = 1
        separator.setLayoutData(grid_data)
      end
    end
  end
end
