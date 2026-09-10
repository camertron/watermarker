module Watermarker
  class Runner
    def initialize(&block)
      @block = block
    end

    def run
      @block.call
    end
  end
end
