# functions to write an MP3 file, uses LAME under the hood

include("lame.jl")

function initialize_writers()
    # nop
end

type MP3FileSink <: SampleSink
    lame::LAME
    info::MP3INFO
    output::IO
end

@inline nchannels(sink::MP3FileSink) = Int(sink.info.nchannels)
@inline samplerate(sink::MP3FileSink) = quantity(Int, Hz)(sink.info.samplerate)
@inline nframes(sink::MP3FileSink) = sink.info.nframes
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
              nchannels::Integer = -1,
              samplerate::Union{Integer, Hertz} = -1,
              bitrate::Integer = 320,
              VBR::Bool = false,
              quality::Number = 4,
              title::AbstractString = "",
              artist::AbstractString = "",
              album::AbstractString = "",
              year::AbstractString = "",
              comment::AbstractString = "")

    stream = savestream(file, MP3INFO(buf);
                        nchannels = nchannels,
                        samplerate = samplerate,
                        bitrate = bitrate,
                        VBR = VBR,
                        quality = quality,
                        title = title,
                        artist = artist,
                        album = album,
                        year = year,
                        comment = comment)

    try
        frameswritten = write(stream, buf)
        if frameswritten != nframes(buf)
            error("Only wrote $frameswritten frames, expected $(nframes(buf))")
        end
    finally
        # make sure we close the file even if something goes wrong
        close(stream)
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

function savestream(path::File, info::MP3INFO;
                    nchannels::Integer = -1,
                    samplerate::Union{Integer, Hertz} = -1,
                    bitrate::Integer = 320,
                    VBR::Bool = false,
                    quality::Number = 4,
                    title::AbstractString = "",
                    artist::AbstractString = "",
                    album::AbstractString = "",
                    year::AbstractString = "",
                    comment::AbstractString = "")

    lame = lame_init()
    lame_set_num_samples(lame, info.nframes)
    lame_set_in_samplerate(lame, info.samplerate)


    # default to the source channels
    if nchannels < 0
        nchannels = info.nchannels
    end
    if nchannels == 1
        lame_set_num_channels(lame, 1)
        lame_set_mode(lame, LAME_MONO)
        info.nchannels = 1
    elseif nchannels == 2
        lame_set_num_channels(lame, 2)
        lame_set_mode(lame, LAME_JOINT_STEREO)
        info.nchannels = 2
    else
        error("the output channels should be either mono (1) or stereo (2)")
    end

    # default to the source sample rate
    if typeof(samplerate) == Hertz
        samplerate = samplerate.val
    end
    if samplerate < 0
        samplerate = info.samplerate
    end
    if !(samplerate in [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000])
        error("sample rate $samplerate Hz is not supported")
    end
    lame_set_out_samplerate(lame, samplerate)

    if VBR == false
        # CBR mode
        lame_set_brate(lame, bitrate)
        lame_set_quality(lame, quality)
    else
        # VBR mode
        lame_set_VBR(lame)
        lame_set_VBR_quality(lame, quality)
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
    id3buffer = Array(UInt8, id3size)
    lame_get_id3v2_tag(lame, id3buffer, id3size) == id3size || error("failed to get ID3v2 buffer")

    output = open(filename(path), "w")
    write(output, id3buffer)

    MP3FileSink(lame, info, output)
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

    # save audio corresponding to one frame
    framelength = 1152
    # the worst case estimate of mp3 buffer length; 8640 when framelength = 1152
    mp3buf_size = ceil(Int, 1.25 * framelength + 7200)
    # TODO: don't allocate here every time we write
    mp3buf = Base.unsafe_convert(Ptr{UInt8}, Array(UInt8, mp3buf_size))

    written = 0
    while written < framecount
        nsamples = min(framelength, framecount - written)
        l = left + written * encsize
        r = right + written * encsize
        bytes = lame_encode_buffer!(lame, l, r, nsamples, mp3buf, mp3buf_size)
        write(sink.output, mp3buf, bytes)

        written += nsamples
    end

    bytes = lame_encode_flush_nogap(lame, mp3buf, mp3buf_size)
    write(sink.output, mp3buf, bytes)

    written
end

function Base.close(sink::MP3FileSink)
    err = lame_close(sink.lame)
    if err != 0
        error("Could not close LAME handle: ", err)
    end

    close(sink.output)
end
