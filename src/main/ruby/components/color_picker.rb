module Watermarker
  module Components
    class ColorPicker < Component
      attr_reader :color

      def initialize(color:)
        @color = color
        @on_color_chosen = []
      end

      def set_background(*args)
        @grid.set_background(*args)
      end

      def set_layout_data(*args)
        @grid.set_layout_data(*args)
      end

      def on_color_chosen(&block)
        @on_color_chosen << block
      end

      def render_in(shell, parent)
        @grid = Grid.new(columns: 2)
        @grid.render_in(shell, parent) do |grid|
          grid.margin_width = 0
          grid.margin_height = 0

          grid.with_item do |grid|
            @swatch = SWT::Canvas.new(grid, SWT::Base.DOUBLE_BUFFERED)
            @swatch.setBackground(@grid.get_background)

            @swatch.addListener(SWT::Base.Paint, Listener.new do |e|
              area = e.widget.getClientArea
              e.gc.setBackground(@color)
              e.gc.fillOval(0, 0, area.width, area.height)
              e.gc.setForeground(SWT::Color.new(70, 70, 70))
              e.gc.drawOval(0, 0, area.width - 1, area.height - 1)
            end)

            @swatch.setLayoutData(SWT::GridData.new(20, 20));
          end

          grid.with_item do |grid|
            color_button = SWT::Button.new(grid, SWT::Base.PUSH);

            color_button.addListener(SWT::Base.Selection, Listener.new do |e|
              dialog = SWT::ColorDialog.new(shell)
              dialog.setRGB(@color.getRGB)
              rgb = dialog.open

              if rgb
                @color = SWT::Color.new(shell.getDisplay, rgb)
                @swatch.redraw

                @on_color_chosen.each do |callback|
                  callback.call(@color)
                end
              end
            end)

            color_button.setText("Choose...")
            color_button.setLayoutData(SWT::GridData.new(SWT::Base.END, SWT::Base.CENTER, true, false))
            color_button.pack
          end

          yield self if block_given?
        end
      end
    end
  end
end
