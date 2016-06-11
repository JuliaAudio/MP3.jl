# mpg123 wrappers of required functions to read mp3 files

# mpg123 encodings
const MPG123_ENC_8           = 0x00f                                            # 0000 0000 0000 1111 Some 8 bit  integer encoding.
const MPG123_ENC_16          = 0x040                                            # 0000 0000 0100 0000 Some 16 bit integer encoding.
const MPG123_ENC_24          = 0x4000                                           # 0100 0000 0000 0000 Some 24 bit integer encoding.
const MPG123_ENC_32          = 0x100                                            # 0000 0001 0000 0000 Some 32 bit integer encoding.
const MPG123_ENC_SIGNED      = 0x080                                            # 0000 0000 1000 0000 Some signed integer encoding.
const MPG123_ENC_FLOAT       = 0xe00                                            # 0000 1110 0000 0000 Some float encoding.
const MPG123_ENC_SIGNED_16   = MPG123_ENC_16 | MPG123_ENC_SIGNED | 0x10         # 0000 0000 1101 0000 signed 16 bit
const MPG123_ENC_UNSIGNED_16 = MPG123_ENC_16 | 0x20                             # 0000 0000 0110 0000 unsigned 16 bit
const MPG123_ENC_UNSIGNED_8  = 0x01                                             # 0000 0000 0000 0001 unsigned 8 bit
const MPG123_ENC_SIGNED_8    = MPG123_ENC_SIGNED | 0x02                         # 0000 0000 1000 0010 signed 8 bit
const MPG123_ENC_ULAW_8      = 0x04                                             # 0000 0000 0000 0100 ulaw 8 bit
const MPG123_ENC_ALAW_8      = 0x08                                             # 0000 0000 0000 0100 alaw 8 bit
const MPG123_ENC_SIGNED_32   = MPG123_ENC_32 | MPG123_ENC_SIGNED | 0x1000       # 0001 0001 1000 0000 signed 32 bit
const MPG123_ENC_UNSIGNED_32 = MPG123_ENC_32 | 0x2000                           # 0010 0001 0000 0000 unsigned 32 bit
const MPG123_ENC_SIGNED_24   = MPG123_ENC_24 | MPG123_ENC_SIGNED | 0x1000       # 0101 0000 1000 0000 signed 24 bit
const MPG123_ENC_UNSIGNED_24 = MPG123_ENC_24 | 0x2000                           # 0110 0000 0000 0000 unsigned 24 bit
const MPG123_ENC_FLOAT_32    = 0x200                                            # 0000 0010 0000 0000 32bit float
const MPG123_ENC_FLOAT_64    = 0x400                                            # 0000 0100 0000 0000 64bit float

# Any possibly known encoding from the list above.
const MPG123_ENC_ANY = ( MPG123_ENC_SIGNED_16  | MPG123_ENC_UNSIGNED_16
	                   | MPG123_ENC_UNSIGNED_8 | MPG123_ENC_SIGNED_8
	                   | MPG123_ENC_ULAW_8     | MPG123_ENC_ALAW_8
	                   | MPG123_ENC_SIGNED_32  | MPG123_ENC_UNSIGNED_32
	                   | MPG123_ENC_SIGNED_24  | MPG123_ENC_UNSIGNED_24
	                   | MPG123_ENC_FLOAT_32   | MPG123_ENC_FLOAT_64    )


typealias PCM16Sample Fixed{Int16, 15}
typealias PCM32Sample Fixed{Int32, 31}

# convert mpg123 encoding to julia datatype
function encoding_to_type(encoding)
    mapping = Dict{Integer, Type}(
       MPG123_ENC_SIGNED_16 => PCM16Sample,
    )

    encoding in keys(mapping) || error("Unsupported encoding $encoding")
    mapping[encoding]
end

typealias Handle Ptr{Void}

const MPG123_DONE               = -12
const MPG123_NEW_FORMAT         = -11
const MPG123_NEED_MORE          = -10
const MPG123_ERR                = -1
const MPG123_OK                 = 0

"""returns a string that explains given error code"""
function mpg123_plain_strerror(err)
    str = ccall((:mpg123_plain_strerror, libmpg123), Ptr{Cchar}, (Cint,), err)
    bytestring(str)
end

"""initialize mpg123 library"""
function mpg123_init()
    err = ccall((:mpg123_init, libmpg123), Cint, ())
    if err != MPG123_OK
        error("Could not initialize mpg123: ", mpg123_plain_strerror(err))
    end
end

"""create new mpg123 handle"""
function mpg123_new()
    err = Ref{Cint}(0)
    handle = ccall((:mpg123_new, libmpg123), Handle,
                   (Ptr{Cchar}, Ref{Cint}),
                   C_NULL, err)

    if err.x != MPG123_OK
        error("Could not create mpg123 handle: ", mpg123_plain_strerror(err.x))
    end

    handle
end

"""opens a mp3 file at fiven path"""
function mpg123_open!(handle::Handle, path::AbstractString)
    err = ccall((:mpg123_open, libmpg123), Cint,
                (Handle, Ptr{Cchar}),
                handle, path)

    if err != MPG123_OK
        mpg123_delete(handle)
        error("Could not open $path: ", mpg123_plain_strerror(err))
    end

    err
end

"""closes a file that is opened by given handle"""
function mpg123_close!(handle::Handle)
    err = ccall((:mpg123_close, libmpg123), Cint, (Handle,), handle)

    if err != MPG123_OK
        warn("Could not close handle $handle: ", mpg123_plain_strerror(err))
    end

    err
end

"""deletes mpg123 handle"""
function mpg123_delete!(handle::Handle)
    ccall((:mpg123_delete, libmpg123), Cint, (Handle,), handle)
end

"""
returns birtate, number of channels and encoding of mp3 file,
opened by given handle
"""
function mpg123_getformat(handle::Handle)
    bitrate = Ref{Clong}(0)
    nchannels = Ref{Cint}(0)
    encoding = Ref{Cint}(0)
    err = ccall((:mpg123_getformat, libmpg123), Cint,
                (Handle, Ref{Clong}, Ref{Cint}, Ref{Cint}),
                handle, bitrate, nchannels, encoding)

    if err != MPG123_OK
        error("Could not read format: ", mpg123_plain_strerror(err))
    end

    bitrate.x, nchannels.x, encoding.x
end

"""returns the appropriate block size for handling this mpg123 handle"""
function mpg123_outblock(handle::Handle)
    ccall((:mpg123_outblock, libmpg123), Csize_t, (Handle,), handle)
end

"""returns the number of samples in the file"""
function mpg123_length(handle::Handle)
    length = ccall((:mpg123_length, libmpg123), Coff_t, (Handle,), handle)
    if length == MPG123_ERR
        error("Could not determine the frame length")
    end
    convert(Int64, length)
end

"""returns how many bytes a sample (in a channel) uses"""
function mpg123_encsize(encoding::Cint)
    ccall((:mpg123_encsize, libmpg123), Cint, (Cint,), encoding)
end

"""
read audio samples from the handle

# Arguments
* `handle::Handle`: the mpg123 handle
* `out::Array{T}`: Array with appropriate data type, to store the samples
* `size::Integer`: the amount to read, in bytes. nchannels * encsize * nsamples
"""
function mpg123_read!{T}(handle::Handle, out::Array{T}, size::Integer)
    done = Ref{Csize_t}(0)
    err = ccall((:mpg123_read, libmpg123), Cint,
                (Handle, Ptr{T}, Csize_t, Ref{Csize_t}),
                handle, out, size, done)

    if err != MPG123_OK && err != MPG123_DONE
        error("Error while reading $handle: ", mpg123_plain_strerror(err))
    end

    done.x
end
