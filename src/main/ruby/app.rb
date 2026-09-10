$:.push(__dir__)

project_root = Polyglot.import("projectRoot")
smoke_exit_ms = Polyglot.import("smokeExitMs")

ENV["LANG"] ||= "en_US.UTF-8"
ENV["LC_ALL"] ||= "en_US.UTF-8"

ENV["BUNDLE_GEMFILE"] ||= File.join(project_root, "Gemfile")
ENV["BUNDLE_PATH"] ||= File.join(project_root, "vendor", "bundle")

# TruffleRuby's digest/sha1 path probes these on macOS before Prawn starts up.
ENV["OPENSSL_PREFIX"] ||= File.join(project_root, "vendor", "openssl")
ENV["LIBYAML_PREFIX"] ||= File.join(project_root, "vendor", "libyaml")

require "json"
bundle_manifest_file = File.join(File.join(__dir__, "bundle_paths.json"))

if File.exist?(bundle_manifest_file)
  JSON.parse(File.read(bundle_manifest_file)).each do |path|
    $:.push(File.join(__dir__, path))
  end
else
  require "bundler/setup"
end

require "prawn"

require "swt"
require "document"
require "component"
require "components"
require "listener"
require "runner"
require "theme"

display = SWT::Display.new
theme = display.isSystemDarkTheme ? Watermarker::DarkTheme : Watermarker::LightTheme

options = {
  text: "DRAFT",
  angle: 35,
  color: SWT::Color.new(0, 0, 0),
  opacity: 20,
}

JavaThread = Java.type("java.lang.Thread")

def show_pdf_error_msg(shell, document)
  shell.getDisplay.asyncExec(-> {
    error_msg = SWT::MessageBox.new(shell, SWT::Base.ICON_ERROR | SWT::Base.OK)
    error_msg.setMessage("There was a problem watermarking #{File.basename(document.input_file)}")
    error_msg.open
  })
end

begin
  shell = SWT::Shell.new(display, SWT::Base.CLOSE | SWT::Base.MIN | SWT::Base.TITLE)
  shell.setText("Watermarker")
  shell.setSize(540, 487)
  shell.setBackground(theme.background_color)

  client_area = shell.getClientArea
  canvas_width = client_area.width
  canvas_height = 220

  progress_bar = nil

  Watermarker::Components::DropCanvas.new.render_in(shell, shell) do |zone|
    zone.set_size(canvas_width, canvas_height)

    zone.on_files_received do |input_files|
      progress_bar.setMinimum(0)
      progress_bar.setSelection(0)
      progress_bar.setVisible(true)

      thread = JavaThread.new(Watermarker::Runner.new do
        zone.enabled = false

        documents = input_files.map do |input_file|
          Watermarker::Document.new(input_file)
        end

        if (invalid_doc = documents.find(&:invalid?))
          show_pdf_error_msg(shell, invalid_doc)

          display.asyncExec(-> {
            progress_bar.setVisible(false)
            zone.enabled = true
          })

          next
        end

        total_page_count = documents.sum(&:page_count)
        total_processed = 0

        display.asyncExec(-> {
          progress_bar.setMaximum(total_page_count)
        })

        documents.each do |document|
          output_path = File.dirname(document.input_file)
          output_basename = File.basename(document.input_file)
          output_prefix = output_basename.chomp(".pdf")
          output_file = File.join(output_path, "#{output_prefix}-watermarked.pdf")

          begin
            document.watermark(output_file, options) do |processed_pages, total_pages|
              display.asyncExec(-> {
                progress_bar.setSelection(total_processed + processed_pages)
              })
            end
          rescue
            show_pdf_error_msg(shell, document)
          end

          total_processed += document.page_count
        end

        display.asyncExec(-> {
          progress_bar.setVisible(false)
          zone.enabled = true
        })
      end)

      thread.start
    end
  end

  settings_list = Watermarker::Components::SettingsList.new
  settings_list.render_in(shell, shell) do |settings_list|
    settings_list.set_location(15, canvas_height)
    settings_list.set_background(theme.background_color)

    settings_list.with_item(label: "Text") do |parent|
      SWT::Text.new(parent, SWT::Base.BORDER | SWT::Base.SMOOTH).tap do |text_field|
        text_field.setText(options[:text])

        text_field.addListener(SWT::Base.KeyUp, Watermarker::Listener.new do |e|
          options[:text] = e.widget.getText
        end)

        setBezelStyle = SWT::CocoaOS.sel_registerName("setBezelStyle:")
        SWT::CocoaOS.objc_msgSend(text_field.view.id, setBezelStyle, 1);
      end
    end

    settings_list.with_item(label: "Angle") do |parent|
      SWT::Combo.new(parent, SWT::Base.DROP_DOWN | SWT::Base.READ_ONLY).tap do |angle_combo|
        angle_options = (0..90).step(5).to_a
        angle_combo.setItems(angle_options.map(&:to_s))
        angle_combo.select(angle_options.index(options[:angle]))

        angle_combo.addListener(SWT::Base.Selection, Watermarker::Listener.new do |e|
          options[:angle] = angle_options[e.widget.getSelectionIndex]
        end)
      end
    end

    settings_list.with_item(label: "Color", width: nil) do |parent|
      Watermarker::Components::ColorPicker.new(color: options[:color]).tap do |color_picker|
        color_picker.render_in(shell, parent) do |color_picker|
          color_picker.set_background(theme.inputs_background_color)
          color_picker.set_layout_data(SWT::GridData.new(SWT::Base.END, SWT::Base.CENTER, true, false))
          color_picker.on_color_chosen do |color|
            options[:color] = color
          end
        end
      end
    end

    settings_list.with_item(label: "Opacity") do |parent|
      SWT::Scale.new(parent, SWT::Base.HORIZONTAL).tap do |opacity_slider|
        opacity_slider.setMinimum(1)
        opacity_slider.setMaximum(100)
        opacity_slider.setSelection(options[:opacity])
        opacity_slider.setIncrement(1)

        opacity_slider.addListener(SWT::Base.Selection, Watermarker::Listener.new do |e|
          options[:opacity] = e.widget.getSelection
        end)

        opacity_slider.pack
      end
    end
  end

  size = settings_list.get_size
  location = settings_list.get_location
  settings_list.set_size(canvas_width - 30, size.y)

  Watermarker::Components::Grid.new(columns: 2).render_in(shell, shell) do |footer|
    footer.set_location(location.x - 5, location.y + size.y + 10)
    footer.set_size(canvas_width - 25, 30)
    footer.set_background(theme.background_color)
    footer.margin_height = 0
    footer.margin_width = 0

    footer.with_item do |parent|
      quit_button = SWT::Button.new(parent, SWT::Base.PUSH);
      quit_button.setText("Quit")

      quit_button.addListener(SWT::Base.Selection, Watermarker::Listener.new do |e|
        shell.dispose
      end)

      quit_button.setLayoutData(SWT::GridData.new(SWT::Base.BEGINNING, SWT::Base.CENTER, false, false))
      quit_button.pack
    end

    footer.with_item do |parent|
      progress_bar = SWT::ProgressBar.new(parent, SWT::Base.HORIZONTAL | SWT::Base.SMOOTH)
      progress_bar.setVisible(false)
      grid_data = SWT::GridData.new(SWT::Base.END, SWT::Base.CENTER, true, false)
      grid_data.widthHint = 200
      progress_bar.setLayoutData(grid_data)
    end
  end

  shell.layout(true, true)

  if smoke_exit_ms && !smoke_exit_ms.empty?
    display["timerExec(int,java.lang.Runnable)"].call(
      smoke_exit_ms.to_i,
      -> { shell.dispose unless shell.isDisposed }
    )
  end

  shell.open

  until shell.isDisposed
    display.sleep unless display.readAndDispatch
  end
ensure
  display.dispose unless display.isDisposed
end
