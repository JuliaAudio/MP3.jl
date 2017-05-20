# lame wrappers of required functions to write mp3 files

"""represents the C pointer lame_global_flags*. used by all LAME functions"""
const LAME = Ptr{Void}

"""meaning of LAME return codes, usually only relevant to lame_encode_buffer families"""
LAME_ERRORS = Dict{Int, String}(
    -1 => "mp3buf was too small",
    -2 => "malloc() problem",
    -3 => "lame_init_params() not called",
    -4 => "psycho acoustic problems"
)

LAME_JOINT_STEREO = 1
LAME_MONO = 3

lame_error_string(ret) = get(LAME_ERRORS, ret, "unknown error code $ret")

"""return the version of LAME library"""
function get_lame_version()
    version = ccall((:get_lame_version, libmp3lame), Ptr{UInt8}, ())
    bytestring(version)
end

"""initialize LAME encoder and return the LAME object"""
function lame_init()
    lame = ccall((:lame_init, libmp3lame), LAME, ())
    if lame == C_NULL
        error("Could not initialize LAME encoder")
    end
    lame
end

"""set the number of samples of the input signal"""
function lame_set_num_samples(lame::LAME, nsamples::Integer)
    ret = ccall((:lame_set_num_samples, libmp3lame), Cint,
                (LAME, Culong), lame, nsamples)

    if ret != 0
        error("Unknown error while calling lame_set_num_samples(): $ret")
    end
end

"""set the sampling rate of the input signal in Hz; default = 44100"""
function lame_set_in_samplerate(lame::LAME, samplerate::Integer)
    ret = ccall((:lame_set_in_samplerate, libmp3lame), Cint,
                (LAME, Cint), lame, samplerate)

    if ret != 0
        error("Unknown error while calling lame_set_in_samplerate(): $ret")
    end
end

"""set the number of channels in the input signal; default = 2"""
function lame_set_num_channels(lame::LAME, nchannels::Integer)
    ret = ccall((:lame_set_num_channels, libmp3lame), Cint,
                (LAME, Cint), lame, nchannels)

    if ret != 0
        error("Error while calling lame_set_num_channels(); should be 1 or 2")
    end
end

"""set the sampling rate of the output signal in Hz"""
function lame_set_out_samplerate(lame::LAME, samplerate::Integer)
    ret = ccall((:lame_set_out_samplerate, libmp3lame), Cint,
                (LAME, Cint), lame, samplerate)

    if ret != 0
        error("Unknown error while calling lame_set_out_samplerate(): $ret")
    end
end

"""set the quality for algorithm selection; should be [0..9]"""
function lame_set_quality(lame::LAME, quality::Integer)
    ret = ccall((:lame_set_quality, libmp3lame), Cint,
                (LAME, Cint), lame, quality)

    if ret != 0
        error("Unknown error while calling lame_set_quality(): $ret")
    end
end

"""set the channel encoding mode; usually 1 (LAME_JOINT_STEREO) or 3 (LAME_MONO)"""
function lame_set_mode(lame::LAME, mode::Integer)
    ret = ccall((:lame_set_mode, libmp3lame), Cint,
                (LAME, Cint), lame, mode)

    if ret != 0
        error("Unknown error while calling lame_set_mode(): $ret")
    end
end

"""set the bitrate of the mp3 output, in kbps"""
function lame_set_brate(lame::LAME, bitrate::Integer)
    ret = ccall((:lame_set_brate, libmp3lame), Cint,
                (LAME, Cint), lame, bitrate)

    if ret != 0
        error("Unknown error while calling lame_set_brate(): $ret")
    end
end

"""enable VBR mode"""
function lame_set_VBR(lame::LAME)
    # call the c function with vbr_mtrh = 4
    ret = ccall((:lame_set_VBR, libmp3lame), Cint,
                (LAME, Cint), lame, 4)

    if ret != 0
        error("Unknown error while calling lame_set_VBR(): $ret")
    end
end

"""set VBR quality; 0.000=highest, 9.999=lowest; """
function lame_set_VBR_quality(lame::LAME, quality::Number)
    # call the c function with vbr_mtrh = 4
    ret = ccall((:lame_set_VBR_quality, libmp3lame), Cint,
                (LAME, Cfloat), lame, Float32(quality))

    if ret != 0
        error("Error while calling lame_set_VBR_quality(); is the quality in [0,9]?")
    end
end

"""set internal parameters based on provided settings"""
function lame_init_params(lame::LAME)
    ccall((:lame_init_params, libmp3lame), Cint, (LAME,), lame)
end

"""print the configuration"""
function lame_print_config(lame::LAME)
    ccall((:lame_print_config, libmp3lame), Cint, (LAME,), lame)
end

"""write 16-bit fixed-point PCM samples"""
function lame_encode_buffer!(lame::LAME, left::Ptr{PCM16Sample}, right::Ptr{PCM16Sample},
                             nsamples::Integer, mp3buf::Ptr{UInt8}, mp3buf_size::Integer)
    ret = ccall((:lame_encode_buffer, libmp3lame), Cint,
                (LAME, Ptr{PCM16Sample}, Ptr{PCM16Sample}, Cint, Ptr{UInt8}, Cint),
                lame, left, right, Cint(nsamples), mp3buf, Cint(mp3buf_size))

    if ret < 0
        error("Error while calling lame_encode_buffer(): ", lame_error_string(ret))
    end

    ret
end

"""write interleaved 16-bit fixed-point PCM samples"""
function lame_encode_buffer_interleaved!(lame::LAME, pcm::Ptr{PCM16Sample},
                                         nsamples::Integer, mp3buf::Ptr{UInt8}, mp3buf_size::Integer)
    ret = ccall((:lame_encode_buffer_interleaved, libmp3lame), Cint,
                (LAME, Ptr{PCM16Sample}, Cint, Ptr{UInt8}, Cint),
                lame, pcm, Cint(nsamples), mp3buf, Cint(mp3buf_size))

    if ret < 0
        error("Error while calling lame_encode_buffer_interleaved(): ", lame_error_string(ret))
    end

    ret
end

"""flush any internal PCM buffers to finalize an MP3 file"""
function lame_encode_flush!(lame::LAME, mp3buf::Ptr{UInt8}, mp3buf_size::Integer)
    ret = ccall((:lame_encode_flush, libmp3lame), Cint,
                (LAME, Ptr{UInt8}, Cint), lame, mp3buf, mp3buf_size)

    if ret < 0
        error("Error while calling lame_encode_flush(): ", lame_error_string(ret))
    end

    ret
end

"""flush any internal PCM buffers to finalize an MP3 file, without ID3v1 tags"""
function lame_encode_flush_nogap(lame::LAME, mp3buf::Ptr{UInt8}, mp3buf_size::Integer)
    ret = ccall((:lame_encode_flush_nogap, libmp3lame), Cint,
                (LAME, Ptr{UInt8}, Cint), lame, mp3buf, mp3buf_size)

    if ret < 0
        error("Error while calling lame_encode_flush_nogap(): ", lame_error_string(ret))
    end

    ret
end

"""free all LAME buffers to finalize the encoder"""
function lame_close(lame::LAME)
    ccall((:lame_close, libmp3lame), Cint, (LAME,), lame)
end

"""initialize ID3 tag"""
function id3tag_init(lame::LAME)
    ccall((:id3tag_init, libmp3lame), Void, (LAME,), lame)
end

"""tell LAME to add ID3v2"""
function id3tag_add_v2(lame::LAME)
    ccall((:id3tag_add_v2, libmp3lame), Void, (LAME,), lame)
end

"""force using ID3v2 and not ID3v1"""
function id3tag_v2_only(lame::LAME)
    ccall((:id3tag_v2_only, libmp3lame), Void, (LAME,), lame)
end

"""set ID3v2 unicode tag for title"""
function id3tag_set_title(lame::LAME, title::AbstractString)
    id3tag_set_textinfo_utf16(lame, "TIT2", title)
end

"""set ID3v2 unicode tag for artist"""
function id3tag_set_artist(lame::LAME, artist::AbstractString)
    id3tag_set_textinfo_utf16(lame, "TPE1", artist)
end

"""set ID3v2 unicode tag for album"""
function id3tag_set_album(lame::LAME, album::AbstractString)
    id3tag_set_textinfo_utf16(lame, "TALB", album)
end

"""set ID3v2 unicode tag for year"""
function id3tag_set_year(lame::LAME, year::AbstractString)
    id3tag_set_textinfo_utf16(lame, "TYER", year)
end

"""set ID3v2 unicode tag for comment"""
function id3tag_set_comment(lame::LAME, comment::AbstractString)
    id3tag_set_comment_utf16(lame, comment)
end

"""get the ID3v2 buffer"""
function lame_get_id3v2_tag(lame::LAME, buffer::Array{UInt8}, size::Integer)
    ccall((:lame_get_id3v2_tag, libmp3lame), Csize_t,
          (LAME, Ptr{UInt8}, Csize_t),
          lame, buffer, size)
end

"""prevent LAME from writing ID3 tags"""
function lame_set_write_id3tag_automatic(lame::LAME, v::Integer)
    ccall((:lame_set_write_id3tag_automatic, libmp3lame), Void,
          (LAME, Cint), lame, v)
end

"""set ID3v2 tag of given id"""
function id3tag_set_textinfo_utf16(lame::LAME, id::AbstractString, text::AbstractString)
    # utf-16 representation of the text, along with the BOM
    data = [0xfeff; utf16(text).data]

    ret = ccall((:id3tag_set_textinfo_utf16, libmp3lame), Cint,
                (LAME, Cstring, Ptr{Cushort}),
                lame, id, data)

    if ret != 0
        error("Unexpected error $ret while calling id3tag_set_textinfo_utf16")
    end
end

"""set ID3v2 comment"""
function id3tag_set_comment_utf16(lame::LAME, text::AbstractString)
    # utf-16 representation of the text, along with the BOM
    data = [0xfeff; utf16(text).data]

    ret = ccall((:id3tag_set_comment_utf16, libmp3lame), Cint,
                (LAME, Ptr{Cchar}, Ptr{Cushort}, Ptr{Cushort}),
                lame, C_NULL, C_NULL, data)

    if ret != 0
        error("Unexpected error $ret while calling id3tag_set_comment_utf16")
    end
end
