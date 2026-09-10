module Watermarker
  class Theme
    attr_reader :background_color, :inputs_background_color, :drop_target_active_color

    def initialize(
      background_color:,
      inputs_background_color:,
      drop_target_active_color:,
    )
      @background_color = background_color
      @inputs_background_color = inputs_background_color
      @drop_target_active_color = drop_target_active_color
    end
  end

  DarkTheme = Theme.new(
    background_color: SWT::Color.new(33, 37, 39),
    inputs_background_color: SWT::Color.new(39, 44, 45),
    drop_target_active_color: SWT::Color.new(20, 20, 20)
  )

  LightTheme = Theme.new(
    background_color: SWT::Color.new(33, 37, 39),
    inputs_background_color: SWT::Color.new(39, 44, 45),
    drop_target_active_color: SWT::Color.new(20, 20, 20)
  )
end
