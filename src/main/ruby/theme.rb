module Watermarker
  class Theme
    attr_reader :background_color, :inputs_background_color, :inputs_separator_color, :drop_target_border_color, :drop_target_active_color

    def initialize(
      background_color:,
      inputs_background_color:,
      inputs_separator_color:,
      drop_target_border_color:,
      drop_target_active_color:
    )
      @background_color = background_color
      @inputs_background_color = inputs_background_color
      @inputs_separator_color = inputs_separator_color
      @drop_target_border_color = drop_target_border_color
      @drop_target_active_color = drop_target_active_color
    end
  end

  DarkTheme = Theme.new(
    background_color: SWT::Color.new(33, 37, 39),
    inputs_background_color: SWT::Color.new(39, 44, 45),
    inputs_separator_color: SWT::Color.new(49, 54, 55),
    drop_target_border_color: SWT::Color.new(100, 100, 100),
    drop_target_active_color: SWT::Color.new(20, 20, 20),
  )

  LightTheme = Theme.new(
    background_color: SWT::Color.new(255, 255, 255),
    inputs_background_color: SWT::Color.new(247, 247, 247),
    inputs_separator_color: SWT::Color.new(236, 236, 236),
    drop_target_border_color: SWT::Color.new(180, 180, 180),
    drop_target_active_color: SWT::Color.new(220, 220, 220),
  )
end
