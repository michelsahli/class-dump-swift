# class-dump-swift

Right now this requires LLVM to parse mach-o's and get symbols from them. Hopefully we'll make it a bit more modular in the future so it doesn't depend on LLVM (since it is a big compile/install)

To get this working:

Download llvm source tree from http://llvm.org/releases/3.9.0/llvm-3.9.0.src.tar.xz (or newer will probably work fine).

    cd llvm-3.9.0.src/
    mkdir build
    cd build
    cmake ..
    make && sudo make install

Then you can successfully compile this project with just `make`. 

Be sure to have Xcode installed and it's command line tools

`xcode-select --install`

This version of class-dump-swift uses the official command line tool from the Swift SDK to demangle the Swift symbols. It's slower but has more compatibility with the different Swift versions.

This makes the tool dependent on the macOS system because the Swift command tools are embedded in Xcode.

The options `-compact` and `-simplified` from the official command tool are implemented.

## Usage

`swiftd [-compact|-simplified] swift_binary_file`

## Alternative

A faster alternative could be to use `nm` to get the Swift symbols. But they won't be grouped per class.

`nm swift_binary_file | xcrun swift-demangle`
