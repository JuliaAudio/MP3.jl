using BinDeps

@BinDeps.setup

mpg123 = library_dependency("libmpg123", aliases=["libmpg123", "libmpg123-0"])
lame = library_dependency("libmp3lame")

provides(AptGet, "libmpg123-dev", mpg123)
provides(AptGet, "libmp3lame-dev", lame)

provides(Pacman, "mpg123", mpg123)
provides(Pacman, "lame", lame)

@static if is_apple()
    if Pkg.installed("Homebrew") === nothing
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
    end
    using Homebrew
    provides(Homebrew.HB, "mpg123", mpg123)
    provides(Homebrew.HB, "lame", lame)
end

@static if is_windows()
    if Sys.WORD_SIZE == 32
        provides(Binaries, URI("http://www.rarewares.org/files/mp3/libmp3lame-3.99.5x86.zip"), lame,
                 SHA="7bf2a33de715d968e5ef5049b7b18e34b9ae98224842293adcdc6f6f23ad9b76",
                 unpacked_dir=".")
        provides(Binaries, URI("http://www.mpg123.org/download/win32/1.24.0/mpg123-1.24.0-x86.zip"), mpg123,
                 SHA="331a48db899f6405b7728a4fcd9ee3ef0282f1d27d983bdc8b0738314bb780cb",
                 unpacked_dir="mpg123-1.24.0-x86")
    elseif Sys.WORD_SIZE == 64
        provides(Binaries, URI("http://www.rarewares.org/files/mp3/libmp3lame-3.99.5x64.zip"), lame,
                 SHA="97959980490caa1669b1c4af386c3e23fe4ceed0835c04e328c9a5966e4d2521",
                 unpacked_dir=".")
        provides(Binaries, URI("http://www.mpg123.org/download/win64/1.24.0/mpg123-1.24.0-x86-64.zip"), mpg123,
                 SHA="d3c21a6f62204a8c93c3f48288f6f7b4d7609394daa966f2d1e6c75b30476f85",
                 unpacked_dir="mpg123-1.24.0-x86-64")
    else
        error("System not 32-bit or 64-bit. Something is wrong")
    end
end

@BinDeps.install Dict("libmpg123" => :libmpg123, "libmp3lame" => :libmp3lame)
