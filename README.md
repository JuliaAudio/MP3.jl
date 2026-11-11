# MP3

*This project is unmaintained*

[![Tests](https://github.com/JuliaAudio/MP3.jl/actions/workflows/Tests.yml/badge.svg)](https://github.com/JuliaAudio/MP3.jl/actions/workflows/Tests.yml)
[![codecov.io](https://codecov.io/github/JuliaAudio/MP3.jl/coverage.svg?branch=master)](https://app.codecov.io/github/JuliaAudio/MP3.jl?branch=master)

MP3 is a [Julia](https://julialang.org/) library for reading and writing MP3 files.

## Usage

The API follows the idioms of [FileIO](https://github.com/JuliaIO/FileIO.jl), and uses [SampleBuf](https://github.com/JuliaAudio/SampledSignals.jl) type to store audio samples. This should supplement [LibSndFile](https://github.com/JuliaAudio/LibSndFile.jl) which does not support MP3 for patent issues.

### Loading MP3

```julia
julia> using MP3

julia> audio = load("Sour_Tennessee_Red_Sting.mp3")
245376-frame, 2-channel SampleBuf{FixedPointNumbers.Fixed{Int16,15}, 2, SIUnits.SIQuantity{Int64,0,0,-1,0,0,0,0,0,0}}
5.564081632653061 s at 44100 s⁻¹
▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▆▆▆▇▇▇▇▆▆▅▄▄▄▄▄▄▇▇▇▇▇▆▇▇▇▇▇▆▅▅▄▄▃▃▃▃▃▂▂▂▁▂▁▁▁
▇▇▇▆▇▇▇▆▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▆▆▅▇▇▆▆▆▅▅▄▄▄▅▄▃▇▇▇▇▇▆▇▇▇▇▆▆▅▄▄▄▄▃▃▃▃▂▂▂▁▂▁▁▁
```

### Saving MP3

Various options for encoding MP3 files can be specified using keyword arguments to `save()` function. An ID3v2 block will be added in front of the file, and the following tags can be optionally given as keyword arguments: `title`, `artist`, `album`, `year`, `comment`.

```julia
julia> save("mono.mp3", audio; nchannels = 1)           # save as mono audio

julia> save("small.mp3", audio; bitrate = 128)          # set bitrate to 128kbps

julia> save("vbr.mp3", audio; VBR = true, quality = 0)  # encode as highest-quality VBR

julia> save("down.mp3", audio; samplerate = 8kHz)       # downsample to 8 kHz
```

## License

This [Julia](https://julialang.org/) library is distributed under MIT license. It uses [LAME](https://lame.sourceforge.io/) for encoding and [mpg123](https://www.mpg123.de/) for decoding mp3, which are dynamically linked, binding to the terms of their LGPL.
