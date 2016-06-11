__precompile__()

module MP3

deps = Pkg.dir("MP3", "deps", "deps.jl")
isfile(deps)? include(deps) : error("MP3 is not properly installed. Please run: Pkg.build(\"MP3\")")

# package code goes here
using SampledSignals
using FileIO
using FixedPointNumbers
using SIUnits

# methods to override
import SampledSignals: nchannels, nframes, samplerate, unsafe_read!, unsafe_write
import FileIO: load, save

# re-export
export load, save

type MP3INFO
    nframes::Int64
    samplerate::Int32
    nchannels::Int32
    encoding::Int32
    encsize::Int32
end

include("readers.jl")
include("writers.jl")

function __init__()
    initialize_readers()

    # MP3 files with ID3v1 (or no tags) and ID3v2 tags have different headers
    magic = (UInt8[0xff, 0xfb], UInt8[0x49, 0x44, 0x33])
    add_format(format"MP3", magic, [".mp3"], [:MP3])
end

end # module
