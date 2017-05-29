# functions to read an MP3 file, uses mpg123 under the hood

include("mpg123.jl")

function initialize_readers()
    # initialize mpg123; this needs to be done only once
    mpg123_init()
end

mutable struct MP3FileSource{T} <: SampleSource
    path::AbstractString
    mpg123::MPG123
    info::MP3INFO
    pos::Int64
    readbuf::Array{T, 2}
end

function MP3FileSource(path::AbstractString, mpg123::MPG123, info::MP3INFO, bufsize::Integer)
    readbuf = Array{info.datatype}(info.nchannels, bufsize)
    MP3FileSource(path, mpg123, info, Int64(0), readbuf)
end

@inline nchannels(source::MP3FileSource) = Int(source.info.nchannels)
@inline samplerate(source::MP3FileSource) = source.info.samplerate
@inline nframes(source::MP3FileSource) = source.info.nframes
@inline Base.eltype{T}(source::MP3FileSource{T}) = T

"""convert mpg123 encoding to julia datatype"""
function encoding_to_type(encoding)
    mapping = Dict{Integer, Type}(
       MPG123_ENC_SIGNED_16 => PCM16Sample,
       # TODO: support more
    )

    encoding in keys(mapping) || error("Unsupported encoding $encoding")
    mapping[encoding]
end

"""
loads an MP3 file as SampledSignals.SampleBuf.

# Arguments
* `file::File{format"MP3"}`: the MP3 file to open
* `blocksize::Int`: the size of block to read from the disk at one time.
                   defaults to the outblock size of the MP3 file.
"""
function load(file::File{format"MP3"}; blocksize = -1)
    source = loadstream(file; blocksize = blocksize)
    buffer = try
        read(source)
    finally
        close(source)
    end
    buffer
end

@inline loadstream(path::AbstractString, args...; kwargs...) =
    loadstream(query(path), args...; kwargs...)

function loadstream(f::Function, args...; kwargs...)
    str = loadstream(args...; kwargs...)
    try
        f(str)
    finally
        close(str)
    end
end

function loadstream(path::File{format"MP3"}; blocksize = -1)
    mpg123 = mpg123_new()
    mpg123_open(mpg123, path.filename)
    nframes = mpg123_length(mpg123)
    samplerate, nchannels, encoding = mpg123_getformat(mpg123)
    if blocksize < 0
        blocksize = mpg123_outblock(mpg123)
    end
    datatype = encoding_to_type(encoding)
    encsize = sizeof(datatype)

    info = MP3INFO(nframes, nchannels, samplerate, datatype)
    bufsize = div(blocksize, encsize * nchannels)
    MP3FileSource(filename(path), mpg123, info, bufsize)
end

function unsafe_read!(source::MP3FileSource, buf::Array, frameoffset, framecount)
    total = min(framecount, nframes(source) - source.pos)
    nread = 0

    mpg123 = source.mpg123
    encsize = sizeof(source.info.datatype)
    readbuf = source.readbuf
    nchans = nchannels(source)

    while nread < total
        n = min(size(readbuf, 2), total - nread)
        nr = mpg123_read!(mpg123, readbuf, n * encsize * nchans)
        nr = div(nr, encsize * nchans)

        transpose!(view(buf, (1:nr)+nread+frameoffset, :), view(readbuf, :, 1:nr))

        source.pos += nr
        nread += nr
        nr == n || break
    end

    nread
end

# @inline function Base.read(source::MP3FileSource)
#     read(source, nframes(source) - source.pos)
# end

@inline function Base.close(source::MP3FileSource)
    mpg123_close(source.mpg123)
    mpg123_delete(source.mpg123)
end
