 """
Created in February, 2022 by
[chifi - an open source software dynasty.](https://github.com/orgs/ChifiSource)
by team
[toolips](https://github.com/orgs/ChifiSource/teams/toolips)
This software is MIT-licensed.
#### | olive | - | custom developer |
Welcome to olive! olive is an integrated development environment written in
julia and for other languages and data editing. Crucially, olive is abstract
    in definition and allows for the creation of unique types for names.
##### Module Composition
- [**Toolips**](https://github.com/ChifiSource/Toolips.jl)
"""
module Olive
import Base: write, display, getindex, setindex!
using IPy
using IPy: Cell
using Pkg
using Toolips
import Toolips: AbstractRoute, AbstractConnection, AbstractComponent, Crayon, write!, Modifier
using ToolipsSession
import ToolipsSession: bind!, AbstractComponentModifier
using ToolipsDefaults
using ToolipsMarkdown
using ToolipsBase64
using TOML
using Revise


#==
- Olive.jl./src/Olive.jl
-- deps/includes  (you are here)
-- default routes
-- extension loader
-- Server Defaults
- [Core.jl](./src/Core.jl)
-- OliveExtensions
-- OliveModifiers
-- Directories
-- Projects
-- server extension
-- display
-- filetracker
- [UI.jl](./src/UI.jl)
-- styles
- [Extensions.jl](./src/Extensions.jl)
==#

include("Core.jl")
include("UI.jl")

"""
main(c::Connection) -> _
--------------------
This function is temporarily being used to test Olive.

"""
main = route("/session") do c::Connection
    c[:OliveCore].client_data[getip(c)][:selected] = "session"
    write!(c, olivesheet())
    proj_open::Project{<:Any} = c[:OliveCore].open[getip(c)]
    ui_topbar::Component{:div} = topbar(c)
    ui_explorer::Component{:div} = projectexplorer()
    olivemain::Component{:div} = olive_main(first(proj_open.open)[1])
    ui_tabs::Vector{Servable} = Vector{Servable}()
    prog::Component{:progress} = ToolipsDefaults.progress("myprog")
    olivemain[:children] = [prog]
    ui_explorer[:children] = [olive_loadicon()]
    bod = body("mainbody")
    push!(bod, ui_explorer, olivemain)
    #bindcheck!(c)
    if ~(:keybindings in keys(c[:OliveCore].client_data[getip(c)]))
        c[:OliveCore].client_data[getip(c)][:keybindings] = Dict(
        :evaluate => ("Enter", :shift),
        :delete => ("Delete", :ctrl, :shift),
        :up => ("ArrowUp", :ctrl, :shift),
        :down => ("ArrowDown", :ctrl, :shift),
        :copy => ("C", :ctrl, :shift),
        :paste => ("V", :ctrl, :shift),
        :cut => ("X", :ctrl, :shift),
        :new => ("Q", :ctrl, :shift)
        )
    end
    olmod::Module = c[:OliveCore].olmod
    mainpane = div("olivemain-pane")
    push!(olivemain, ui_topbar, mainpane)
    on(c, "load") do cm::ComponentModifier
        load_extensions!(c, cm, olmod)
        cells::Vector{Servable} = Base.invokelatest(olmod.build, c,
        cm, proj_open)
        mainpane[:children] = cells
        set_children!(cm, "olivemain", [ui_topbar, mainpane])

    end
    write!(c, bod)
end

explorer = route("/") do c::Connection
    c[:OliveCore].client_data[getip(c)][:selected] = "files"
    loader_body = div("loaderbody", align = "center")
    style!(loader_body, "margin-top" => 10percent)
    write!(c, olivesheet())
    icon = olive_loadicon()
    bod = olive_body(c)
    on(c, bod, "load") do cm::ComponentModifier
        olmod = c[:OliveCore].olmod
        homeproj = Directory(c[:OliveCore].data[:home], "root" => "rw")
        publicproj = Directory(c[:OliveCore].data[:public],
        "public" => "rw")
        dirs = [homeproj, publicproj]
        main = olive_main("files")
        for dir in dirs
            push!(main[:children], build(c, cm, dir, olmod))
        end
        script!(c, cm, "loadcallback") do cm
            style!(cm, icon, "opacity" => 0percent)
            set_children!(cm, bod, [olivesheet(), main])
        end
        load_extensions!(c, cm, olmod)
    end
    push!(loader_body, icon)
    push!(bod, loader_body)
    write!(c, bod)
 end


dev = route("/") do c::Connection
    explorer.page(c)
end

setup = route("/") do c::Connection

end

fourofour = route("404") do c::Connection
    write!(c, p("404message", text = "404, not found!"))
end

function create_project(homedir::String = homedir(), olivedir::String = ".olive")
        @info "welcome to olive! to use olive, you will need to setup a project directory."
        @info "we can put this at $homedir/$olivedir, is this okay with you?"
        print("y or n: ")
        response = readline()
        if response == "y"
            try
                cd(homedir)
                Toolips.new_webapp(olivedir)
        catch
            throw("unable to access your applications directory.")
        end
        open("$homedir/$olivedir/src/olive.jl", "w") do o
            write(o, """
            module $olivedir
            using Toolips
            using ToolipsSession
            using Olive
            import Olive: build

            build(oc::OliveCore) = begin
                oc::OliveCore
            end

            end # module""")
        end
        @info "olive files created! welcome to olive! "
    end
end

"""
start(IP::String, PORT::Integer, extensions::Vector{Any}) -> ::Toolips.WebServer
--------------------
The start function comprises routes into a Vector{Route} and then constructs
    a ServerTemplate before starting and returning the WebServer.
"""
function start(IP::String = "127.0.0.1", PORT::Integer = 8000;
    devmode::Bool = false)
    if devmode
        s = OliveDevServer(OliveCore("Dev"))
        s.start()
        s[:Logger].log("started new olive server in devmode.")
        return
    end
    startup_path::String = pwd()
    homedirec::String = homedir()
    olivedir::String = "olive"
    oc::OliveCore = OliveCore("olive")
    rs::Vector{AbstractRoute} = Vector{AbstractRoute}()
    if ~(isdir("$homedirec/$olivedir"))
        proj = create_project(homedirec, olivedir)
        Pkg.activate("$homedirec/$olivedir/.")
        rs = routes(setup, fourofour)
    else
        Pkg.activate("$homedirec/$olivedir")
        olmod = eval(Meta.parse(read("$homedirec/$olivedir/src/olive.jl", String)))
        Base.invokelatest(olmod.build, oc)
        rs = routes(fourofour, main, explorer)
    end
    server = ServerTemplate(IP, PORT, rs, extensions = [OliveLogger(),
    oc, Session(["/", "/session"])])
    server.start(); server::Toolips.ToolipsServer
end

OliveServer(oc::OliveCore) = WebServer(extensions = [oc, OliveLogger(),
Session(["/", "/session"])])

OliveDevServer(oc::OliveCore) = begin
    rs = routes(dev, fourofour, main)
    WebServer(extensions = [oc, OliveLogger(), Session(["/", "/session"])],
    routes = rs)
end

#== TODO Create creates a new server at the current directory, making Olive.jl
deployable!
==#
function create(name::String)
    Toolips.new_webapp(name)
    Pkg.add(url = "https://github.com/ChifiSource/Olive.jl")
    open("$name/src/$name.jl") do io
        write!(io, """
        module $name
        using Toolips
        using ToolipsSession
        using Olive
        import Olive: build

        build(oc::OliveCore) = begin
            oc::OliveCore
        end

        build(om::OliveModifier, oe::OliveExtension{:$name})

        end

        function start()

        end

        end # module
        """)
    end
end

export OliveCore, build
end # - module
