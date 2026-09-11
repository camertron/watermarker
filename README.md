# Watermarker

Watermarker is a neat little MacOS app that watermarks .pdf files. It's written in Ruby and compiles to native via TruffleRuby. The UI is built on SWT, which works out-of-the-box with TruffleRuby and GraalVM.

![foo](/screenshot.png "Screenshot of the Watermarker UI")

## Getting Started

If all you want to do is _use_ the Watermarker app, head over to the [releases](https://github.com/camertron/watermarker/releases) page and download it.

If you want to build it on your own computer, then follow the instructions below.

## Local Development

First, make sure you have all the necessary SDKs and build tools installed. This is most easily done via an installer like [asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/). I personally used mise for this project, so that's probably what you should use too.

Once mise is installed, run `mise install` to install all the necessary build tools, SDKs, etc. You'll probably also need to install [Homebrew](https://brew.sh/) first, and use it to install openssl and libyaml: `brew install openssl libyaml`.

### Installing Gems

Now that all the build tools and such are installed, you need to install all the gem dependencies:

```bash
bundle install
```

### Running the App

You should now be able to run the app via:

```bash
scripts/run
```

That will launch the app and let you play around with it. Try dragging a .pdf file onto the drop zone. It should spit out a "*-watermarked.pdf" file next to the original.

## Releasing

The following steps will produce a signed .app file you can stick into your Applications directory.

### Building the Native Image

First you'll need to compile the "native image," which is the base executable produced by GraalVM that forms the heart of the app. Once the native image is built, you shouldn't have to build it again unless you change the project's Java helpers. To build the native image, run:

```bash
scripts/native
```

### Packaging

Produce the .app file by running:

```bash
scripts/bundle
```

This will produce a Watermarker.app file in the project's root directory.

## License

MIT

## Authors

* Cameron C. Dutro, i.e. [@camertron](https://github.com/camertron)
