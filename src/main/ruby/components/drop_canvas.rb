module Watermarker
  module Components
    class DropCanvas
      BACKGROUND_COLOR = SWT::Color.new(33, 37, 39)
      ACTIVE_BACKGROUND_COLOR = SWT::Color.new(20, 20, 20)

      def initialize
        @background_color = BACKGROUND_COLOR
        @on_files_received = []
      end

      def on_files_received(&block)
        @on_files_received << block
      end

      def render_in(shell, parent)
        @canvas = SWT::Canvas.new(parent, SWT::Base.DOUBLE_BUFFERED)

        @canvas.addListener(SWT::Base.Paint, Listener.new do |e|
          paint(e.gc, shell)
        end)

        @canvas.addListener(SWT::Base.Dispose, Listener.new do |e|
          @canvas_message_font&.dispose
        end)

        @drop_target = SWT::DropTarget.new(@canvas, SWT::DND.DragOver | SWT::DND.Drop | SWT::DND.DROP_COPY)
        @drop_target.setTransfer([SWT::FileTransfer.getInstance])

        @drop_target.addListener(SWT::DND.DragOver, Listener.new do |e|
          e.detail = SWT::DND.DROP_COPY
          self.active = true
        end)

        @drop_target.addListener(SWT::DND.DragLeave, Listener.new do |e|
          self.active = false
        end)

        @drop_target.addListener(SWT::DND.Drop, Listener.new do |e|
          self.active = false

          next if e.data.nil?
          input_files = e.data.to_a.map(&:to_s)

          if input_files.any? { |f| File.extname(f) != ".pdf" }
            error_msg = SWT::MessageBox.new(shell, SWT::Base.ICON_ERROR | SWT::Base.OK)
            error_msg.setMessage("Only .pdf files can be watermarked.")
            error_msg.open
            next
          end

          @on_files_received.each do |callback|
            callback.call(input_files)
          end
        end)

        yield self if block_given?
      end

      def set_size(*args)
        @canvas.setSize(*args)
      end

      def enabled=(value)
        if value
          @drop_target.setTransfer([SWT::FileTransfer.getInstance])
        else
          @drop_target.setTransfer([])
        end
      end

      def active=(value)
        if value
          @background_color = ACTIVE_BACKGROUND_COLOR
        else
          @background_color = BACKGROUND_COLOR
        end

        @canvas.redraw
      end

      private

      def paint(gc, shell)
        @canvas.setBackground(@background_color)

        area = @canvas.getClientArea
        folder_icon_path = File.join(__dir__, "..", "folder.png")
        folder_icon = SWT::Image.new(shell.getDisplay, folder_icon_path)
        image_data = folder_icon.getImageData
        aspect_ratio = image_data.width.to_f / image_data.height.to_f
        folder_icon_width = 100
        folder_icon_height = folder_icon_width * aspect_ratio

        gc.setLineStyle(SWT::Base.LINE_DASH)
        gc.setLineWidth(5)
        gc.setForeground(SWT::Color.new(100, 100, 100))
        gc.setBackground(@background_color)
        gc.fillRoundRectangle(20, 20, area.width - 40, area.height - 40, 20, 20)
        gc.drawRoundRectangle(20, 20, area.width - 40, area.height - 40, 20, 20)

        gc.drawImage(
          folder_icon,
          (area.width / 2) - (folder_icon_width / 2),
          40,
          folder_icon_width,
          folder_icon_height
        )

        @canvas_message_font ||= begin
          new_font_data = gc.getFont.getFontData.tap do |font_data|
            font_data.each do |font|
              font.setHeight(16)
            end
          end

          SWT::Font.new(shell.getDisplay, new_font_data)
        end

        gc.setFont(@canvas_message_font)

        message = "Drop .pdf files here"
        extent = gc.stringExtent(message)

        gc.drawString(message, (area.width / 2) - (extent.x / 2), 40 + folder_icon_height + 15)
      end
    end
  end
end
