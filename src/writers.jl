# functions to write an MP3 file, uses LAME under the hood

include("lame.jl")

function initialize_writers()
    # nop
end

# number of frames in 1 MP3 block
const MP3_BLOCKFRAMES = 1152
# max size needed to hold the encoded mp3 data for a full block
const MP3_BUFBYTES = ceil(Int, 1.25 * MP3_BLOCKFRAMES + 7200)

mutable struct MP3FileSink <: SampleSink
    lame::LAME
    samplerate::Int
    nchannels::Int
    output::IO
    nframes::Int
    mp3buf::Vector{UInt8}
end

function MP3FileSink(lame, samplerate, nchannels, output)
    MP3FileSink(lame, samplerate, nchannels, output, 0, Array{UInt8}(MP3_BUFBYTES))
end

@inline nchannels(sink::MP3FileSink) = sink.nchannels
@inline samplerate(sink::MP3FileSink) = sink.samplerate
@inline nframes(sink::MP3FileSink) = sink.nframes
@inline Base.eltype(sink::MP3FileSink) = PCM16Sample

"""
save an MP3 file, using parameters as specified

# Arguments
* `file::File`: the MP3 file to save
* `buf::SampleBuf`: the audio buffer to save
* `nchannels::Int`: whether the output should be mono (1) or stereo (2)
* `samplerate::Int`: the sample rate, default is to retain the original;
                     will raise an error if the value is not one of
                     8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000
* `bitrate::Int`: the bitrate in kbps, used for CBR
* `VBR::Bool`: whether to use VBR (false by default)
* `quality::Int`: 0 for highest quality, 9 for lowest quality (default 4)
                  used as algorithm selector for CBR and quality level for VBR.
* others: ID3v2 tag items to be added
"""
function save(file::File, buf::SampleBuf;
        samplerate=SampledSignals.samplerate(buf), nchannels=SampledSignals.nchannels(buf),
        kwargs...)
    savestream(file; samplerate=samplerate, nchannels=nchannels, kwargs...) do stream
        frameswritten = write(stream, buf)
        if frameswritten != nframes(buf)
            error("Only wrote $frameswritten frames, expected $(nframes(buf))")
        end
    end

    nothing
end

@inline savestream(path::AbstractString, args...; kwargs...) =
    savestream(query(path), args...; kwargs...)

function savestream(f::Function, args...; kwargs...)
    stream = savestream(args...; kwargs...)
    try
        f(stream)
    finally
        close(stream)
    end
end

function savestream(path::File;
                    nchannels = 2,
                    samplerate = 44100,
                    bitrate = 320,
                    VBR = false,
                    quality = 4,
                    title = "",
                    artist = "",
                    album = "",
                    year = "",
                    comment = "")

    lame = lame_init()
    # lame_set_num_samples(lame, info.nframes)

    if nchannels == 1
        lame_set_num_channels(lame, 1)
        lame_set_mode(lame, LAME_MONO)
    elseif nchannels == 2
        lame_set_num_channels(lame, 2)
        lame_set_mode(lame, LAME_JOINT_STEREO)
    else
        error("the output channels should be either mono (1) or stereo (2)")
    end

    if !(samplerate in [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000])
        error("sample rate $samplerate Hz is not supported")
    end
    # resampling is handled by SampledSignals
    lame_set_in_samplerate(lame, Int(samplerate))
    lame_set_out_samplerate(lame, Int(samplerate))

    if VBR == false
        # CBR mode
        lame_set_brate(lame, Int(bitrate))
        lame_set_quality(lame, Int(quality))
    else
        # VBR mode
        lame_set_VBR(lame)
        lame_set_VBR_quality(lame, Int(quality))
    end

    id3tag_init(lame)
    id3tag_add_v2(lame)
    id3tag_v2_only(lame)
    isempty(title)   || id3tag_set_title(lame, title)
    isempty(artist)  || id3tag_set_artist(lame, artist)
    isempty(album)   || id3tag_set_album(lame, album)
    isempty(year)    || id3tag_set_year(lame, year)
    isempty(comment) || id3tag_set_comment(lame, comment)
    lame_set_write_id3tag_automatic(lame, 0)

    lame_init_params(lame)

    id3size = lame_get_id3v2_tag(lame, UInt8[], 0)
    id3buffer = Array{UInt8}(id3size)
    lame_get_id3v2_tag(lame, id3buffer, id3size) == id3size || error("failed to get ID3v2 buffer")

    output = open(filename(path), "w")
    write(output, id3buffer)

    MP3FileSink(lame, samplerate, nchannels, output)
end

function unsafe_write(sink::MP3FileSink, buf::Array, frameoffset, framecount)
    lame = sink.lame

    # the data in the buffer is not interleaved; we pass them separately
    encsize = sizeof(PCM16Sample)
    left = channelptr(buf, 1, frameoffset)
    # the right-channel pointer only gets accessed for a stereo file, in which
    # case we should have a stereo buffer (because of the SampledSignals
    # conversion)
    right = channelptr(buf, 2, frameoffset)

    mp3buf = pointer(sink.mp3buf)

    written = 0
    while written < framecount
        nframes = min(MP3_BLOCKFRAMES, framecount - written)
        l = left + written * encsize
        r = right + written * encsize
        bytes = lame_encode_buffer!(lame, l, r, nframes, mp3buf, MP3_BUFBYTES)
        Base.unsafe_write(sink.output, mp3buf, bytes)

        written += nframes
    end

    sink.nframes += written
    written
end

function Base.close(sink::MP3FileSink)
    if sink.lame != C_NULL
        mp3buf = pointer(sink.mp3buf)
        bytes = lame_encode_flush_nogap(sink.lame, mp3buf, MP3_BUFBYTES)
        Base.unsafe_write(sink.output, mp3buf, bytes)

        err = lame_close(sink.lame)
        close(sink.output)
        if err != 0
            error("Could not close LAME handle: ", err)
        end
        sink.lame = C_NULL
    end
end
