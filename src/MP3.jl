module MP3

# package code goes here
using SampledSignals
using FileIO
using FixedPointNumbers
using LinearAlgebra
using mpg123_jll
using LAME_jll

# methods to override
import SampledSignals: nchannels, nframes, samplerate, unsafe_read!, unsafe_write

# re-export
export Hz, kHz, s

struct MP3INFO
    nframes::Int64
    nchannels::Int32
    samplerate::Int64
    datatype::DataType
end

"""create an MP3INFO object from given audio buffer"""
function MP3INFO(buf::SampleBuf{T}) where {T}
    MP3INFO(nframes(buf), nchannels(buf), samplerate(buf), T)
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
