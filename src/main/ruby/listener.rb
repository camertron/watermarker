module Watermarker
  class Listener
    def initialize(&block)
      @block = block
    end

    def handleEvent(e)
      @block.call(e)
    end
  end
end
