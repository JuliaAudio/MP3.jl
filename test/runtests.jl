using MP3

if VERSION >= v"0.5.0-dev+7720"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
end

# write your own tests here
@testset "Loading MP3" begin
    reference = load(Pkg.dir("MP3", "test", "Sour_Tennessee_Red_Sting.mp3"))
    @test typeof(reference) == SampledSignals.SampleBuf{MP3.PCM16Sample,2,MP3.Hertz}
    @test size(reference) == (245376, 2)
    @test reference.samplerate == 44100Hz
    @test reference.samplerate == 44.1kHz
end

@testset "Saving MP3" begin
    reference = load(Pkg.dir("MP3", "test", "Sour_Tennessee_Red_Sting.mp3"))

    outpath = "$(tempname()).mp3"
    save(outpath, reference)
    audio = load(outpath)
    @test size(audio) == size(reference)
    @test audio.samplerate == reference.samplerate

    for samplerate in [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
        save(outpath, reference; samplerate = samplerate)
        audio = load(outpath)
        @test audio.samplerate == samplerate * Hz
    end

    for bitrate in [96, 128, 160, 192, 224, 256, 320]
        save(outpath, reference; bitrate = bitrate)
        audio = load(outpath)
        @test size(audio) == size(reference)
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
end
