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

"""represents the C pointer mpg123_handle*. used by all mpg123 functions"""
const MPG123 = Ptr{Void}

const MPG123_DONE               = -12
const MPG123_NEW_FORMAT         = -11
const MPG123_NEED_MORE          = -10
const MPG123_ERR                = -1
const MPG123_OK                 = 0

"""return a string that explains given error code"""
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
    mpg123 = ccall((:mpg123_new, libmpg123), MPG123,
                   (Ptr{Cchar}, Ref{Cint}),
                   C_NULL, err)

    if err.x != MPG123_OK
        error("Could not create mpg123 handle: ", mpg123_plain_strerror(err.x))
    end

    mpg123
end

"""open an mp3 file at fiven path"""
function mpg123_open(mpg123::MPG123, path::AbstractString)
    err = ccall((:mpg123_open, libmpg123), Cint,
                (MPG123, Ptr{Cchar}),
                mpg123, path)

    if err != MPG123_OK
        mpg123_delete(mpg123)
        error("Could not open $path: ", mpg123_plain_strerror(err))
    end

    err
end

"""close a file that is opened by given handle"""
function mpg123_close(mpg123::MPG123)
    err = ccall((:mpg123_close, libmpg123), Cint, (MPG123,), mpg123)

    if err != MPG123_OK
        warn("Could not close mpg123 $mpg123: ", mpg123_plain_strerror(err))
    end

    err
end

"""delete mpg123 handle"""
function mpg123_delete(mpg123::MPG123)
    ccall((:mpg123_delete, libmpg123), Cint, (MPG123,), mpg123)
end

"""return birtate, number of channels and encoding of the mp3 file"""
function mpg123_getformat(mpg123::MPG123)
    bitrate = Ref{Clong}(0)
    nchannels = Ref{Cint}(0)
    encoding = Ref{Cint}(0)
    err = ccall((:mpg123_getformat, libmpg123), Cint,
                (MPG123, Ref{Clong}, Ref{Cint}, Ref{Cint}),
                mpg123, bitrate, nchannels, encoding)

    if err != MPG123_OK
        error("Could not read format: ", mpg123_plain_strerror(err))
    end

    bitrate.x, nchannels.x, encoding.x
end

"""return the appropriate block size for handling this mpg123 handle"""
function mpg123_outblock(mpg123::MPG123)
    ccall((:mpg123_outblock, libmpg123), Csize_t, (MPG123,), mpg123)
end

"""return the number of samples in the file"""
function mpg123_length(mpg123::MPG123)
    length = ccall((:mpg123_length, libmpg123), Int64, (MPG123,), mpg123)
    if length == MPG123_ERR
        error("Could not determine the frame length")
    end
    convert(Int64, length)
end

"""return how many bytes a sample (in a channel) uses"""
function mpg123_encsize(encoding::Cint)
    ccall((:mpg123_encsize, libmpg123), Cint, (Cint,), encoding)
end

"""
read audio samples from the mpg123 handle

# Arguments
* `mpg123::MPG123`: the mpg123 handle
* `out::Array{T}`: Array with appropriate data type, to store the samples
* `size::Integer`: the amount to read, in bytes. nchannels * encsize * nsamples
"""
function mpg123_read!{T}(mpg123::MPG123, out::Array{T}, size::Integer)
    done = Ref{Csize_t}(0)
    err = ccall((:mpg123_read, libmpg123), Cint,
                (MPG123, Ptr{T}, Csize_t, Ref{Csize_t}),
                mpg123, out, size, done)

    if err != MPG123_OK && err != MPG123_DONE
        error("Error while reading $mpg123: ", mpg123_plain_strerror(err))
    end

    Int(done.x)
end
