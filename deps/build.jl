using BinDeps

@BinDeps.setup

mpg123 = library_dependency("libmpg123")
lame = library_dependency("libmp3lame")

provides(AptGet, "libmpg123-dev", mpg123)
provides(AptGet, "libmp3lame-dev", lame)

@osx_only begin
    if Pkg.installed("Homebrew") === nothing
        error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
    end
    using Homebrew
    provides(Homebrew.HB, "mpg123", mpg123)
    provides(Homebrew.HB, "lame", lame)
end

@BinDeps.install Dict("libmpg123" => :libmpg123, "libmp3lame" => :libmp3lame)

