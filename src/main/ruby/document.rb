require "combine_pdf"
require "prawn"

module Watermarker
  class Document
    attr_reader :input_file

    def initialize(input_file)
      @input_file = input_file
    end

    def page_count
      @page_count ||= CombinePDF.load(input_file).pages.size
    end

    def valid?
      page_count
      true
    rescue
      false
    end

    def invalid?
      !valid?
    end

    def watermark(output_file, options, &block)
      return if page_count == 0

      document = CombinePDF.load(input_file)
      swt_color = options[:color]
      color = [swt_color.getRed, swt_color.getGreen, swt_color.getBlue].map { |n| n.to_s(16).rjust(2, "0") }.join

      document.pages.each_with_index do |page, page_idx|
        _, _, page_width, page_height = page[:MediaBox]

        watermark = Prawn::Document.new(margin: 0)
        watermark.delete_page(0)
        watermark.start_new_page(size: [page_width, page_height])
        watermark.fill_color(color)

        max_width = (page_width * 0.65) / Math.cos(options[:angle] * (Math::PI / 180))
        font_size = find_max_font_size(options[:text], max_width, watermark)
        text_width = watermark.width_of(options[:text], size: font_size)
        text_height = watermark.height_of(options[:text], size: font_size)

        # set the page's origin to the center (mostly for rotation)
        watermark.translate(page_width / 2.0, page_height / 2.0) do
          watermark.font_size(font_size) do
            watermark.rotate(options[:angle]) do
              watermark.transparent(options[:opacity] / 100.0) do
                watermark.text_box(
                  options[:text],
                  width: text_width,
                  height: text_height,
                  at: [text_width / -2.0, text_height / 2.0],
                  align: :center,
                  valign: :center,
                  color: color,
                )
              end
            end
          end
        end

        overlay = CombinePDF.parse(watermark.render)
        document.pages[page_idx] << overlay.pages[0]

        block.call(page_idx + 1, page_count)
      end

      document.save(output_file)
    end

    private

    def find_max_font_size(text, max_width, doc)
      max_font_size_cache["#{text}-#{max_width}"] ||= begin
        cur_width = 0
        font_size = 0

        while cur_width < max_width
          font_size += 1
          cur_width = doc.width_of(text, size: font_size)
        end

        font_size
      end
    end

    def max_font_size_cache
      @@max_font_size_cache ||= {}
    end
  end
end
