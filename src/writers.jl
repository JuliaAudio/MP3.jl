# functions to write an MP3 file, uses LAME under the hood

include("lame.jl")

"""
saves an MP3 file

# Arguments
* `file::File{format"MP3"}`: the MP3 file to save
* `bitrate::Int`: the bitrate in kbps, used for CBR
* `VBR::Bool`: whether to use VBR (false by default)
* `quality::Int`: VBR quality, 0 for highest quality, 9 for smallest file (default 4)
"""
function save(file::File{format"MP3"}; bitrate = 320, VBR = false, quality = 4)
    println("TODO: MP3 save")
end
