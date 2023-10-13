#==output[filemap]
==#
#==|||==#
"""
### OliveExtension{P <: Any}
The OliveExtension is a symbolic type that is used by the `build` function in
order to create extensions using an OliveModifier. This constructor should only
be called internally. Instead, simply use methods to define your extension.
##### example
```
# this is your olive root file:
module olive
using Olive
import Olive: build

                            # vv the name of your extension ! vv
function build(om::OliveModifier, oe::OliveExtension{:myextension})
    alert!(om, "hello!")
end
```
------------------
##### constructors
OliveExtension{}
"""
mutable struct OliveExtension{P <: Any} end
#==output[code]
==#
#==|||==#
"""
### OliveModifier <: ToolipsSession.AbstractComponentModifier
- rootc**::Dict{String, AbstractComponent}**
- changes**::Vector{String}**
- data::Dict{String, Any}
The OliveModifier is used whenever an extension is loaded with a `build`
function.
##### example
```
# this is your olive root file:
module olive
using Olive
import Olive: build

                            # vv the name of your extension ! vv
function build(om::OliveModifier, oe::OliveExtension{:myextension})
    alert!(om, "hello!")
end
```
------------------
##### constructors
- OliveExtension{}
"""
mutable struct OliveModifier <: ToolipsSession.AbstractComponentModifier
    rootc::Dict{String, AbstractComponent}
    changes::Vector{String}
    data::Dict{String, Any}
    function OliveModifier(c::Connection, cm::ComponentModifier)
        new(cm.rootc, cm.changes, c[:OliveCore].client_data[getname(c)])
    end
end
#==output[code]
==#
#==|||==#
getindex(om::OliveModifier, symb::Symbol) = om.data[symb]
setindex!(om::OliveModifier, o::Any, symb::Symbol) = setindex!(om.data, o, symb)
#==output[code]
==#
#==|||==#

function load_extensions!(c::Connection, cm::ComponentModifier, olmod::Module)
    mod = OliveModifier(c, cm)
    Base.invokelatest(c[:OliveCore].olmod.build, c, mod,
    OliveExtension{:invoker}())
    signatures = [m.sig.parameters[4] for m in methods(olmod.build,
     [Any, Modifier, OliveExtension])]
    for sig in signatures
        if sig == OliveExtension{<:Any}
            continue
        end
        Base.invokelatest(c[:OliveCore].olmod.build, c, mod, sig())
    end
end

"""
**Olive Core**
### build(c::Connection, om::OliveModifier, oe::OliveExtension{<:Any})
------------------
This is the base `build` function. These functions are ran whenever an extension
is loaded into your root project. This function is not meant to be called, but
extended and written
#### example
```

```
"""
build(c::Connection, om::OliveModifier, oe::OliveExtension{<:Any}) = return
#==output[code]
==#
#==|||==#
build(c::Connection, om::OliveModifier, oe::OliveExtension{:keybinds}) = begin
    # load default key-bindings (if non-existent)
    if ~("keybindings" in keys(c[:OliveCore].client_data[getname(c)]))
        push!(c[:OliveCore].client_data[getname(c)],
        "keybindings" => Dict{String, Any}(
        "evaluate" => ["Enter", "shift"],
        "delete" => ["Delete", "ctrl", "shift"],
        "up" => ["ArrowUp", "ctrl", "shift"],
        "down" => ["ArrowDown", "ctrl", "shift"],
        "copy" => ["C", "ctrl", "shift"],
        "paste" => ["V", "ctrl", "shift"],
        "cut" => ["X", "ctrl", "shift"],
        "new" => ["Enter", "ctrl", "shift"],
        "focusup" => ["ArrowUp", "shift"],
        "focusdown" => ["ArrowDown", "shift"],
        "save" => ["s", "ctrl"],
        "saveas" => ["S", "ctrl", "shift"],
        "open" => ["O", "ctrl"],
        "find" => ["F", "ctrl"]
        ))
    end
    keybind_drop = containersection(c, "keybindings", fillto = 90)
    keybind_section = keybind_drop[:children][2]
    shftlabel = a("shiftlabel", text = "  shift:    ")
    ctrllabel = a("ctrllabel", text = "  ctrl:   ")
    keybind_section[:children] = Vector{Servable}(vcat([h("setkeyslbl", 2, text = "keybindings")],
    [begin
        newkeymain = div("keybind$(keybinding[1])")
        head = h("keylabel$(keybinding[1])",5,  text = "$(keybinding[1])")
        setinput = ToolipsDefaults.keyinput("$(keybinding[1])inp", text = keybinding[2][1])
        style!(setinput, "background-color" => "blue", "width" => 5percent,
        "display" => "inline-block", "color" => "white")
        shift_checkbox = ToolipsDefaults.checkbox("shiftk$(keybinding[1])",
        value = "shift" in keybinding[2])
        ctrl_checkbox = ToolipsDefaults.checkbox("ctrlk$(keybinding[1])",
        value = "ctrl" in keybinding[2])
        confirm = button("keybind$(keybinding[1])confirm", text = "confirm")
        on(c, confirm, "click") do cm::ComponentModifier
            key_vec = Vector{String}()
            k = cm[setinput]["value"]
            if length(k) == 1
                k = uppercase(k)
            end
            push!(key_vec, k)
            if parse(Bool, cm[shift_checkbox]["value"])
                push!(key_vec, "shift")
            end
            if parse(Bool, cm[ctrl_checkbox]["value"])
                push!(key_vec, "ctrl")
            end
            c[:OliveCore].client_data[getname(c)]["keybindings"][keybinding[1]] = key_vec
            olive_notify!(cm, "binding $(keybinding[1]) saved")
        end
        push!(newkeymain, head, shftlabel, shift_checkbox,
        ctrllabel, ctrl_checkbox, setinput, br(), confirm)
        newkeymain
    end for keybinding in c[:OliveCore].client_data[getname(c)]["keybindings"]]))
    append!(om, "settingsmenu", keybind_drop)
end

build(c::Connection, om::OliveModifier, oe::OliveExtension{:creatorkeys}) = begin
    if ~("creatorkeys" in keys(c[:OliveCore].client_data[getname(c)]))
        push!(c[:OliveCore].client_data[getname(c)],
        "creatorkeys" => Dict{String, String}("c" => "code", "v" => "markdown"))
    end
    if om.data["selected"] == "files"
        return
    end
    creatorkeys = c[:OliveCore].client_data[getname(c)]["creatorkeys"]
    creatorkeysdropd = containersection(c, "creatorkeys", text = "creator keys")
    creatorkeysmen = creatorkeysdropd[:children][2]
    regkeys = div("regkeyss")
    regkeys[:children] = [begin
        mainbox = div("creatorkey$(key[1])")
        delet = topbar_icon("$(key[1])delet", "close")
        style!(delet, "color" => "red", "font-size" => 15pt)
        keyname = a("kd", text = key[2])
        binding = a("kb", text = key[1])
        style!(binding, "background-color" => "#FFFDD0",
        "border-radius" => 2px, "padding" => 3px, "color" => "#454545")
        style!(keyname, "margin-left" => 2px, "margin-right" => 2px,
        "color" => "darkblue", "font-weight" => "bold")
        push!(mainbox, delet, keyname, binding)
        on(c, delet, "click") do cm::ComponentModifier
            delete!(creatorkeys, key)
            remove!(cm, mainbox)
        end
        mainbox::Component{:div}
    end for key in creatorkeys]
    push!(creatorkeysmen, h("creatorkeys", 2, text = "creator keys"), regkeys)
    setinput = ToolipsDefaults.keyinput("creatorkeyinp", text = "c")
    style!(setinput, "background-color" => "blue", "width" => 5percent,
    "display" => "inline-block", "color" => "white")
    newsection = div("newcreator")
    push!(newsection, h("news", 4, text = "bind new"), setinput)
    signatures = [m.sig.parameters[4] for m in methods(c[:OliveCore].olmod.build,
    [Toolips.AbstractConnection, Toolips.Modifier, IPyCells.AbstractCell, Project{<:Any}])]
    opts = Vector{Servable}()
    for sig in signatures
        if sig == Cell{:creator} || sig == Cell{<:Any} || sig == Cell{:versioninfo}
            continue
        end
        if length(sig.parameters) < 1
            continue
        end
        b = ToolipsDefaults.option("creatorkey", text = string(sig.parameters[1]))
        push!(opts, b)
    end
    sigselector = ToolipsDefaults.dropdown("sigselector", opts, value = "code")
    style!(sigselector, "background-color" => "white", "margin-left" => 5px,
    "margin-right" => 5px)
    addbutton = button("addcreatekey", text = "add key")
    on(c, addbutton, "click") do cm::ComponentModifier
        sigsel = cm[sigselector]["value"]
        setkey = cm[setinput]["value"]
        creatorkeys[setkey] = sigsel
        olive_notify!(cm, "creator key updated")
    end
    push!(newsection, sigselector, addbutton)
    push!(creatorkeysmen, newsection)
    append!(om, "settingsmenu", creatorkeysdropd)
end

build(c::Connection, om::OliveModifier, oe::OliveExtension{:highlightstyler}) = begin
    if ~("highlighting" in keys(c[:OliveCore].client_data[getname(c)]))
        tm = ToolipsMarkdown.TextStyleModifier("")
        ToolipsMarkdown.highlight_julia!(tm)
        tomltm = ToolipsMarkdown.TextStyleModifier("")
        toml_style!(tomltm)
        dic = Dict{String, Dict{<:Any, <:Any}}()
        push!(c[:OliveCore].client_data[getname(c)], "highlighting" => dic)
        push!(dic, "julia" => Dict{String, String}(
            [string(k) => string(v[1][2]) for (k, v) in tm.styles]))
        push!(dic, "toml" => Dict{String, String}(
            [string(k) => string(v[1][2]) for (k, v) in tomltm.styles]))
    end
    if ~("highlighters" in keys(c[:OliveCore].client_data[getname(c)]))
        highlighting = c[:OliveCore].client_data[getname(c)]["highlighting"]
        julia_highlighter = ToolipsMarkdown.TextStyleModifier("")
        toml_highlighter = ToolipsMarkdown.TextStyleModifier("")
        julia_highlighter.styles = Dict([begin
            Symbol(k[1]) => ["color" => k[2]]
        end for k in c[:OliveCore].client_data[getname(c)]["highlighting"]["julia"]])
        toml_highlighter.styles = Dict([begin
            Symbol(k[1]) => ["color" => k[2]]
        end for k in c[:OliveCore].client_data[getname(c)]["highlighting"]["toml"]])
        push!(c[:OliveCore].client_data[getname(c)], 
        "highlighters" => Dict{String, ToolipsMarkdown.TextStyleModifier}(
            "julia" => julia_highlighter, "toml" => toml_highlighter
        ))
    end
    dic = c[:OliveCore].client_data[getname(c)]["highlighting"]
    container = containersection(c, "highlighting", fillto = 80)
    sect = container[:children][2]
    highheader = h("highlighthead", 3, text = "fonts and highlighting")
    push!(sect, highheader)
    for colorset in keys(dic)
        colorsetbox = div("$colorset-settings")
        push!(colorsetbox, h("$colorset-label", 4, text = colorset))
        [begin 
            label = h("colorlabel", 5, text = color)
            vbox = ToolipsDefaults.colorinput("$(color)$(colorset)", 
            value = "'$(dic[colorset][color])'")
            clrdiv = div("clrdiv$(color)$(colorset)")
            style!(clrdiv, "display" => "inline-block")
            push!(clrdiv, label, vbox)
            push!(colorsetbox, clrdiv)
        end for color in keys(dic[colorset])]
        push!(sect, colorsetbox)
    end
    updatebutton = button("highupdate", text = "apply")
    on(c, updatebutton, "click") do cm::ComponentModifier
        [begin
            hl = c[:OliveCore].client_data[getname(c)]["highlighters"][highlighter[1]]
            styles = Dict([k[1] => cm["$(k[1])$(highlighter[1])"]["value"] for k in dic[highlighter[1]]])
            hl.styles = Dict([Symbol(k[1]) => ["color" => k[2]] for k in styles])
            dic[highlighter[1]] = styles
        end for highlighter in dic]
        olive_notify!(cm, "Your syntax highlighters have been updated", color = "green")
    end
    push!(sect, Component("highsep", "sep
    
    "), updatebutton)
    append!(om, "settingsmenu", container)
end

function save_settings!(c::Connection; core::Bool = false)
    homedir = c[:OliveCore].data["home"]
    alltoml = read("$homedir/Project.toml", String)
    current_toml = TOML.parse(alltoml)
    name = getname(c)
    client_settings = deepcopy(c[:OliveCore].client_data[name])
    [onsave(client_settings, OliveExtension{m.sig.parameters[3].parameters[1]}()) for m in methods(onsave)]
    current_toml["oliveusers"][name] = client_settings
    datakeys = c[:OliveCore].data
    toml_datakeys = keys(current_toml["olive"])
    if core
        [begin
            if datakey[1] in toml_datakeys
                current_toml[datakey[1]] = datakey[2]
            else
                push!(current_toml, datakey[1] => datakey[2])
            end
        end for datakey in datakeys]
    end
    open("$homedir/Project.toml", "w") do io
        TOML.print(io, current_toml)
    end
end

function onsave(cd::Dict{<:Any, <:Any}, oe::OliveExtension{:highlighter})
    delete!(cd, "highlighters")
end

"""
### Directory{S <: Any}
- dirtype::String
- uri::String
- access::Dict{String, Vector{String}}
- cells::Vector{Cell}
The directory type holds Directory information and file cells on startup. It
is built with the `Olive.build(c::Connection, dir::Directory)` method. This holds
cells and directories
##### example
```
```
------------------
##### constructors
- Directory(uri::String, access::Pair{String, String} ...; dirtype::String = "olive")
"""
mutable struct Directory{S <: Any}
    dirtype::String
    uri::String
    access::Dict{String, String}
    cells::Vector{Cell}
    function Directory(uri::String, access::Pair{String, String} ...;
        dirtype::String = "olive")
        file_cells = directory_cells(uri, access ...)
        new{Symbol(dirtype)}(dirtype, uri, Dict(access ...), file_cells)
    end
end

getindex(p::Vector{Directory{<:Any}}, s::String) = begin
    pos = findfirst(dir::Directory{<:Any} -> dir.name == s, p)
    if isnothing(pos)
        throw(KeyError("project $s not found!"))
    end
    p[pos]
end
#==output[code]
==#
#==|||==#
"""
**Interface**
### build(c::Connection, dir::Directory{<:Any}, m::Module, exp::Bool = false) -> ::Component{:div}
------------------
The catchall/default `build` function. If you want to add a custom directory,
create an OliveaExtension and
#### example
```

```
"""
function build(c::Connection, dir::Directory{<:Any}, m::Module)
    becell = replace(dir.uri, "/" => "|")
    dirtext = split(replace(dir.uri, homedir() => "~",), "/")
    if length(dirtext) > 3
        dirtext = join(dirtext[length(dirtext) - 3:length(dirtext)], "/")
    else
        dirtext = join(dirtext, "/")
    end
    if "Project.toml" in readdir(dir.uri)
        toml_cats = TOML.parse(read(dir.uri * "/Project.toml",
        String))
        if "name" in keys(toml_cats)
            dirtext = toml_cats["name"]
        end
        if "type" in keys(toml_cats)
            
        end
    end
    container = containersection(c, becell, text = dirtext)
    containerheader = container[:children][1]
    containerbody = container[:children][2]
    style!(container, "overflow" => "hidden")
    if "home" in keys(c[:OliveCore].data) && dir.uri == c[:OliveCore].data["home"]
        srcbutton = topbar_icon("srchome", "play_arrow")
        on(c, srcbutton, "click") do cm::ComponentModifier
            home = c[:OliveCore].data["home"]
            try
                load_extension!(c[:OliveCore])
                olive_notify!(cm, "olive module successfully sourced!", color = "green")
            catch e
                olive_notify!(cm,
                "failed to source olive module",
                color = "red")
            end
        end
        style!(srcbutton,"font-size" => 20pt, "color" => "red",
        "font-weight" => "bold", "cursor" => "pointer")
        push!(containerheader, srcbutton)
    end
    cells::Vector{Servable} = Vector{Servable}([begin
        Base.invokelatest(m.build, c, cell, dir)
    end for cell in dir.cells])
    cellcontainer = section("$(becell)cells")
    cellcontainer[:children] = cells
    new_dirb = topbar_icon("newdir$(becell)", "create_new_folder")
    new_fb = topbar_icon("newfb$(becell)", "article")
    openworkb = topbar_icon("cd$(becell)", "open_in_browser")
    style!(new_dirb, "font-size" => 20pt, "display" => "inline-block", "color" => "darkgray")
    style!(new_fb, "font-size" => 20pt, "display" => "inline-block", "color" => "darkgray")
    style!(openworkb, "font-size" => 20pt, "display" => "inline-block", "color" => "darkgray")
    push!(containerheader, openworkb, new_dirb, new_fb)
    on(c, openworkb, "click") do cm::ComponentModifier
        switch_work_dir!(c, cm, dir.uri)
    end
    on(c, new_dirb, "click") do cm::ComponentModifier
        create_new_dir!(c, cm, dir)
    end
    on(c, new_fb, "click") do cm::ComponentModifier
        create_new!(c, cm, dir)
    end
    push!(containerbody, cellcontainer)
    return(container)
end

"""
### Project{name <: Any}
- name::String
- dir::String
- directories::Vector{Directory{<:Any}}
- environment::String
- open::Dict{String, Dict{String, Any}}
The directory type holds Directory information and file cells on startup. It
is built with the `Olive.build(c::Connection, dir::Directory)` method. This holds
cells and directories
##### example
```
```
------------------
##### constructors
- Directory(uri::String, access::Pair{String, String} ...; dirtype::String = "olive")
"""
mutable struct Project{name <: Any}
    name::String
    data::Dict{Symbol, Any}
    id::String
    Project{T}(name::String,
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()) where {T <: Any} = begin
        uuid::String = replace(ToolipsSession.gen_ref(10),
        [string(dig) => "" for dig in digits(1234567890)] ...)
        new{T}(name, data, uuid)::Project{<:Any}
    end
end

getindex(p::Project{<:Any}, symb::Symbol) = p.data[symb]

function create_project(homedir::String = homedir(), olivedir::String = "olive")
    try
        cd(homedir)
        Pkg.generate("olive")
    catch
        throw("unable to access your applications directory.")
    end
    open("$homedir/$olivedir/src/olive.jl", "w") do o
        write(o,
        """\"""
        ## welcome to olive!
        Welcome to olive: the multiple dispatch notebook application for Julia.
        This is  your olive home module's file. This is where extensions
        for Olive can be loaded. **Note the distinction in case.**
        This homefile was created using a pre-release version of Olive.

        Thank you for trying Olive.
        - Please report any issues to [our issues page!](https://github.com/ChifiSource/Olive.jl/issues)
        \"""
        #==|||==#
        using Olive
        import Olive: build
        #==output[code]
        this cell starts the module, you probably don't want to run it.
        ==#
        """)
    end
    @info "olive files created! welcome to olive! "
end

getindex(p::Vector{Project{<:Any}}, s::String) = begin
    pos = findfirst(proj::Project{<:Any} -> proj.name == s, p)
    if isnothing(pos)
        throw(KeyError("project $s not found!"))
    end
    p[pos]
end

"""
**Interface**
```
build(c::Connection, cm::ComponentModifier, p::Project{<:Any})
```
------------------
The catchall/default `build` function. If you want to add a custom directory,
create an OliveaExtension and
#### example
```

```
"""
function build(c::AbstractConnection, cm::ComponentModifier, p::Project{<:Any})
    frstcells::Vector{Cell} = p[:cells]
    retvs = Vector{Servable}([begin
        Base.invokelatest(c[:OliveCore].olmod.build, c, cm, cell,
        p)::Component{<:Any}
    end for cell in frstcells])
    proj_window::Component{:div} = div(p.id)
    proj_window[:children] = retvs
    style!(proj_window, "overflow-y" => "scroll", "overflow-x" => "hidden", "padding" => 7px)
    proj_window::Component{:div}
end

mutable struct Environment
    name::String
    directories::Vector{Directory}
    projects::Vector{Project}
    pwd::String
    function Environment(name::String)
        new(name, Vector{Directory}(),
        Vector{Project}(), "")::Environment
    end
end

getindex(e::Environment, proj::String) = e.projects[proj]::Project{<:Any}

getindex(e::Vector{Environment}, name::String) = begin
    pos = findfirst(env::Environment -> env.name == name, e)
    if isnothing(pos)
        throw(KeyError("Environment for $name not found."))
    end
    e[pos]::Environment
end

mutable struct OliveCore <: ServerExtension
    olmod::Module
    type::Vector{Symbol}
    data::Dict{String, Any}
    names::Dict{String, String}
    client_data::Dict{String, Dict{String, Any}}
    open::Vector{Environment}
    pool::Vector{String}
    client_keys::Dict{String, String}
    function OliveCore(mod::String)
        data = Dict{Symbol, Any}()
        m = eval(Meta.parse("module olive end"))
        open = Vector{Environment}()
        pool = Vector{String}()
        client_data = Dict{String, Dict{String, Any}}()
        client_keys::Dict{String, String} = Dict{String, String}()
        new(m, [:connection], data, Dict{String, String}(),
        client_data, open, pool, client_keys)
    end
end

getname(c::Connection) = c[:OliveCore].names[getip(c)]::String

function source_module!(oc::OliveCore)
    homemod = """module olive
    using Olive
    end"""
    pmod = Meta.parse(homemod)
    olmod::Module = Main.evalin(pmod)
    oc.olmod = olmod
end

function load_extensions!(oc::OliveCore)
    homedirec = oc.data["home"]
    olive_cells = IPyCells.read_jl("$homedirec/src/olive.jl")
    filter!(ocell -> ocell.type == "code" || ocell.source != "\n" || cell.source != "\n\n",
    olive_cells)
    modstr = "begin\n" * join(
        [cell.source for cell in olive_cells[1:length(olive_cells)]]) * "\n\nend"
    
    olmod = oc.olmod
    olmod.evalin(Meta.parse(modstr))
end

OliveLogger() = Logger(Dict{Any, Crayon}(
    1 => Crayon(foreground = :blue),
    2 => Crayon(foreground = :magenta),
    3 => Crayon(foreground = :red),
         :time_crayon => Crayon(foreground = :blue),
        :message_crayon => Crayon(foreground = :light_magenta, bold = true)), prefix = "🫒 olive> ")

mutable struct OliveDisplay <: AbstractDisplay
    io::IOBuffer
    OliveDisplay() = new(IOBuffer())::OliveDisplay
end

function display(d::OliveDisplay, m::MIME{:olive}, o::Any)
    T::Type = typeof(o)
    mymimes = [MIME"text/html", MIME"text/svg", MIME"image/png",
    MIME"image/jpeg", MIME"image/gif", MIME"text/markdown",
     MIME"text/plain"]
    correctm = nothing
    for m in mymimes
        try
            correctm = m
            display(d, correctm(), o)
            break
        catch
            continue
        end
    end
end

function display(d::OliveDisplay, m::MIME"text/html", o::Any)
    show(d.io, m, o)
end

function display(d::OliveDisplay, m::MIME"image/png", o::Any)
    show_img(d, o, "png")
end

function display(d::OliveDisplay, m::MIME"image/jpeg", o::Any)
    show_img(d, o, "jpeg")
end

function display(d::OliveDisplay, m::MIME"image/gif", o::Any)
    show_img(d, o, "gif")
end

function show_img(d::OliveDisplay, o::Any, ftype::String)
    show(d.io, MIME"text/html"(), base64img("$(ToolipsSession.gen_ref())", o,
    ftype))
end

function display(d::OliveDisplay, m::MIME"text/plain", o::Any)
    show(d.io, m, o)
end

function display(d::OliveDisplay, m::MIME"text/markdown", o::Any)
    show(d.io, m, o)
end

display(d::OliveDisplay, o::Any) = display(d, MIME{:olive}(), o)
