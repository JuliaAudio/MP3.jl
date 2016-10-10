__precompile__()

module MP3

deps = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
isfile(deps)? include(deps) : error("MP3 is not properly installed. Please run: Pkg.build(\"MP3\")")

# package code goes here
using SampledSignals
using FileIO
using FixedPointNumbers
using SIUnits
using SIUnits.ShortUnits

using Compat
import Compat: UTF8String, view

# methods to override
import SampledSignals: nchannels, nframes, samplerate, unsafe_read!, unsafe_write
import FileIO: load, save

# re-export
export load, save
export Hz, kHz, s

# types used for fixed-point 16-bit and 32-bit encoding
typealias PCM16Sample Fixed{Int16, 15}
typealias PCM32Sample Fixed{Int32, 31}

# shortcut to SIQuantity type of Hz
typealias Hertz SIUnits.SIQuantity{Int64,0,0,-1,0,0,0,0,0,0}

type MP3INFO
    nframes::Int64
    nchannels::Int32
    samplerate::Int32
    datatype::DataType
end

"""create an MP3INFO object from given audio buffer"""
function MP3INFO{T}(buf::SampleBuf{T})
    MP3INFO(size(buf, 1), size(buf, 2), buf.samplerate.val, T)
end

include("readers.jl")
include("writers.jl")

function __init__()
    initialize_readers()
    initialize_writers()

    # MP3 files with ID3v1 (or no tags) and ID3v2 tags have different headers
    magic = (UInt8[0xff, 0xfb], UInt8[0x49, 0x44, 0x33])
    add_format(format"MP3", magic, [".mp3"], [:MP3])
end

end # module
