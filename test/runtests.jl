using MP3
using SampledSignals

using Test

# encoding and decoding can introduce some delay
DELAY_THRESHOLD = 1160

# write your own tests here
@testset "Loading MP3" begin
    reference = load(joinpath(dirname(@__FILE__), "Sour_Tennessee_Red_Sting.mp3"))
    @test typeof(reference) == SampledSignals.SampleBuf{PCM16Sample,2}
    @test size(reference, 2) == 2
    @test abs(size(reference, 1) - 245376) <= DELAY_THRESHOLD
    @test reference.samplerate == 44100
end

@testset "Saving MP3" begin
    # drop the volume so we don't get any clipping during resampling
    reference = load(joinpath(dirname(@__FILE__), "Sour_Tennessee_Red_Sting.mp3")) * 0.9

    outpath = "$(tempname()).mp3"
    save(outpath, reference)
    audio = load(outpath)
    @test size(audio) == size(reference)
    @test audio.samplerate == reference.samplerate

    for samplerate in [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
        save(outpath, reference; samplerate = samplerate)
        audio = load(outpath)
        @test audio.samplerate == samplerate
    end

    for bitrate in [96, 128, 160, 192, 224, 256, 320]
        save(outpath, reference; bitrate = bitrate)
        audio = load(outpath)
        @test size(audio, 2) == size(reference, 2)
        @test abs(size(audio, 1) - size(reference, 1)) <= DELAY_THRESHOLD
    end

    save(outpath, reference[:, 1])
    audio = load(outpath)
    @test size(audio, 2) == 1

    save(outpath, reference[:, 2])
    audio = load(outpath)
    @test size(audio, 2) == 1

    save(outpath, reference[:, 1]; nchannels = 2)
    audio = load(outpath)
    @test size(audio, 2) == 2

    f32 = map(Float32, reference)
    save(outpath, f32)
    audio = load(outpath)
    @test audio.samplerate == 44100
    @test size(audio, 2) == size(reference, 2)
    @test abs(size(audio, 1) - size(reference, 1)) <= DELAY_THRESHOLD

    f64 = map(Float32, reference)
    save(outpath, f64)
    @test audio.samplerate == 44100
    @test size(audio, 2) == size(reference, 2)
    @test abs(size(audio, 1) - size(reference, 1)) <= DELAY_THRESHOLD
end
