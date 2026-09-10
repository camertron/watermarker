# TruffleRuby SWT Native Spike

Tiny Java bootstrap + embedded TruffleRuby + Bundler + SWT window.

## Install Ruby Gems

```sh
bundle config set path vendor/bundle
bundle install
```

## Run on the JVM

```sh
./scripts/run
```

The JVM run uses `-XstartOnFirstThread`, which SWT/Cocoa needs on macOS.
For a non-interactive smoke test, use:

```sh
TRUFFLE_GUI_SMOKE_EXIT_MS=1000 ./scripts/run
```

The sample Ruby app lives in `src/main/ruby/app.rb`. It is loaded from disk at
runtime, not embedded into the native image, so Ruby app changes do not require
a native rebuild. It boots Bundler, requires the app's gems, and drives SWT
directly from Ruby through TruffleRuby's Java interop:

```ruby
require "bundler/setup"
require "prawn"

Display = Java.type("org.eclipse.swt.widgets.Display")
Shell = Java.type("org.eclipse.swt.widgets.Shell")

display = Display.new
shell = Shell.new(display)
shell.setText("TruffleRuby + SWT + prawn #{Prawn::VERSION}")
shell.setSize(640, 420)
```

When passing Ruby callbacks to overloaded Java methods, select the Java
signature explicitly:

```ruby
SWT = Java.type("org.eclipse.swt.SWT")

button["addListener(int,org.eclipse.swt.widgets.Listener)"].call(
  SWT.Selection,
  -> event { puts event }
)
```

## Build a Native Image

```sh
./scripts/native
```

The scripts prefer a local GraalVM JDK under `.graalvm/` when present, then a
valid external `JAVA_HOME`, then the asdf-pinned Oracle JDK for JVM-only runs.
`./scripts/native` requires `native-image` in the selected JDK.

The native build writes:

```sh
target/truffle-gui-native
```

This is a macOS arm64 Mach-O executable. The Native Image metadata in
`src/main/resources/META-INF/native-image/com.example/truffle-gui-native/`
includes SWT/Cocoa JNI metadata plus generated reflection/proxy metadata for
direct Ruby access to SWT classes. `./scripts/native` regenerates that metadata
before compiling; run `./scripts/generate-swt-native-metadata` manually after
changing the SWT dependency if you want to inspect the diff first.

The executable looks for the Ruby entrypoint in this order:

```text
TRUFFLE_GUI_SCRIPT, if set
app.rb beside the detected Gemfile
src/main/ruby/app.rb below the detected Gemfile
../Resources/app.rb from that same root
```

## Current Shape

The native binary loads both the app script and gems from disk at runtime, so
run it from the project root after `bundle install`. For the current
`Watermarker.app` experiment, `Gemfile`, `Gemfile.lock`, `vendor/bundle`, and
`app.rb` live beside the executable in `Contents/MacOS`. SWT is now called
directly from Ruby with `Java.type(...)`; Java remains only as the TruffleRuby
bootstrap and host-class policy.
