// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// This class was created based on the WS2812 library by DHeadrick

class SK6812 {
    // This class uses SPI to emulate the SK6812s' one-wire protocol.
    // This requires one byte per bit to send data at 7.5 MHz via SPI.
    // These consts define the "waveform" to represent a zero or one

    static VERSION = [1,0,0];

    static ZERO            = 0xC0;
    static ONE             = 0xF8;
    static BYTES_PER_PIXEL   = 32;

    // When instantiated, the SK6812 class will fill this array with blobs to
    // represent the waveforms to send the numbers 0 to 255. This allows the
    // blobs to be copied in directly, instead of being built for each pixel.

    static _bits     = array(256, null);

    // Private variables passed into the constructor

    _spi             = null;  // imp SPI interface (pre-configured)
    _frameSize       = null;  // number of pixels per frame
    _frame           = null;  // a blob to hold the current frame

    // Parameters:
    //    spi          A pre-configured SPI bus (MSB_FIRST, 7500)
    //    frameSize    Number of Pixels per frame
    //    _draw        Whether or not to initially draw a blank frame
    constructor(spiBus, frameSize, _draw = true) {
        // spiBus must be configured
        _spi = spiBus;

        _frameSize = frameSize;
        _frame = blob(_frameSize * BYTES_PER_PIXEL + 1);
        _frame[_frameSize * BYTES_PER_PIXEL] = 0;

        // Used in constructing the _bits array
        local bytesPerColor = BYTES_PER_PIXEL / 4;

        // Fill the _bits array if required
        // (Multiple instance of SK6812 will only initialize it once)
        if (_bits[0] == null) {
            for (local i = 0; i < 256; i++) {
                local valblob = blob(bytesPerColor);
                valblob.writen((i & 0x80) ? ONE:ZERO,'b');
                valblob.writen((i & 0x40) ? ONE:ZERO,'b');
                valblob.writen((i & 0x20) ? ONE:ZERO,'b');
                valblob.writen((i & 0x10) ? ONE:ZERO,'b');
                valblob.writen((i & 0x08) ? ONE:ZERO,'b');
                valblob.writen((i & 0x04) ? ONE:ZERO,'b');
                valblob.writen((i & 0x02) ? ONE:ZERO,'b');
                valblob.writen((i & 0x01) ? ONE:ZERO,'b');
                _bits[i] = valblob;
            }
        }

        // Clear the pixel buffer
        fill([0,0,0,0]);

        // Output the pixels if required
        if (_draw) {
            this.draw();
        }
    }

    // Configures the SPI Bus
    //
    // NOTE: If using the configure method, you *must* pass `false` to the
    // _draw parameter in the constructor (or else an error will be thrown)
    function configure() {
        _spi.configure(MSB_FIRST, 7500);
        return this;
    }

    // Sets a pixel in the buffer
    //   index - the index of the pixel (0 <= index < _frameSize)
    //   color - [r,g,b,w] (0 <= r,g,b,w <= 255)

    function set(index, color) {
        index = _checkRange(index);
        color = _checkColorRange(color);

        _frame.seek(index * BYTES_PER_PIXEL);

        // Create a blob for the color
        // Red and green are swapped for some reason, so swizzle them back
        _frame.writeblob(_bits[color[1]]);
        _frame.writeblob(_bits[color[0]]);
        _frame.writeblob(_bits[color[2]]);
        _frame.writeblob(_bits[color[3]]);

        return this;
    }

    // Sets the frame buffer (or a portion of the frame buffer)
    // to the specified color, but does not write it to the pixel strip

    function fill(color, start=0, end=null) {
        // we can't default to _frameSize -1, so we
        // default to null and set to _frameSize - 1
        if (end == null) { end = _frameSize - 1; }

        // Make sure we're not out of bounds
        start = _checkRange(start);
        end = _checkRange(end);
        color = _checkColorRange(color);

        // Flip start & end if required
        if (start > end) {
            local temp = start;
            start = end;
            end = temp;
        }

        // Create a blob for the color
        // Red and green are swapped for some reason, so swizzle them back
        local colorBlob = blob(BYTES_PER_PIXEL);
        colorBlob.writeblob(_bits[color[1]]);
        colorBlob.writeblob(_bits[color[0]]);
        colorBlob.writeblob(_bits[color[2]]);
        colorBlob.writeblob(_bits[color[3]]);

        // Write the color blob to each pixel in the fill
        _frame.seek(start*BYTES_PER_PIXEL);
        for (local index = start; index <= end; index++) {
            _frame.writeblob(colorBlob);
        }

        return this;
    }

    // Writes the frame to the pixel strip

    function draw() {
        _spi.write(_frame);
        return this;
    }

    function _checkRange(index) {
        if (index < 0) index = 0;
        if (index >= _frameSize) index = _frameSize - 1;
        return index;
    }

    function _checkColorRange(colors) {
        foreach(idx, color in colors) {
            if (color < 0) colors[idx] = 0;
            if (color > 255) colors[idx] = 255;
        }
        return colors
    }
}
