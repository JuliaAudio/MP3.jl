# functions to read an MP3 file, uses mpg123 under the hood

include("mpg123.jl")

function initialize_readers()
    # initialize mpg123; this needs to be done only once
    mpg123_init()
end

type MP3FileSource{T} <: SampleSource
    path::AbstractString
    handle::Ptr{Void}
    info::MP3INFO
    pos::Int64
    readbuf::Array{T, 2}
end

function MP3FileSource(path::AbstractString, handle::Handle, info::MP3INFO, bufsize::Integer)
    T = encoding_to_type(info.encoding)
    readbuf = Array(T, info.nchannels, bufsize)

    MP3FileSource(path, handle, info, 0, readbuf)
end

@inline nchannels(source::MP3FileSource) = Int(source.info.nchannels)
@inline samplerate(source::MP3FileSource) = quantity(Int, Hz)(source.info.samplerate)
@inline nframes(source::MP3FileSource) = source.info.nframes
@inline Base.eltype{T}(source::MP3FileSource{T}) = T

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
        readall(source)
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
    handle = mpg123_new()
    mpg123_open!(handle, path.filename)
    nframes = mpg123_length(handle)
    samplerate, nchannels, encoding = mpg123_getformat(handle)
    if blocksize < 0
        blocksize = mpg123_outblock(handle)
    end
    encsize = mpg123_encsize(encoding)

    info = MP3INFO(nframes, samplerate, nchannels, encoding, encsize)
    bufsize = div(blocksize, encsize * nchannels)
    MP3FileSource(filename(path), handle, info, bufsize)
end

function unsafe_read!(source::MP3FileSource, buf::SampleBuf)
    total = min(nframes(buf), nframes(source) - source.pos)
    nread = 0

    handle = source.handle
    encsize = source.info.encsize
    readbuf = source.readbuf
    nchannels = source.info.nchannels

    while nread < total
        n = min(size(readbuf, 2), total - nread)
        nr = mpg123_read!(handle, readbuf, n * encsize * nchannels)
        nr = div(nr, encsize * nchannels)

        for ch in 1:nchannels
            for i in 1:nr
                @inbounds buf[nread + i, ch] = readbuf[ch, i]
            end
        end

        source.pos += nr
        nread += nr
        nr == n || break
    end

    # cast this to be a signed integer; unsigned integer produces an error
    Int(nread)
end

@inline function Base.readall(source::MP3FileSource)
    read(source, nframes(source) - source.pos)
end

@inline function Base.close(source::MP3FileSource)
    mpg123_close!(source.handle)
    mpg123_delete!(source.handle)
end
