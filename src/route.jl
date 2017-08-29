using HTTP

abstract type Matcher end

mutable struct Route
    handler #TODO: restrict it to interface f(req, res)
    matchers::Array{Matcher}
    #regexpgroup ::Regexpgroup
    function Route(handler, path, methods, host, headers)
        matchers = []
        if path != nothing
            pathmatcher = newmatcher(path, "path")
            push!(matchers, pathmatcher)
        end
        if host!=nothing
            hostmatcher = newmatcher(host, "host")
            push!(matchers, hostmatcher)
        end
        if methods != nothing
            methodmatcher = newmethodmatcher(methods)
            push!(matchers, methodmatcher)
        end
        if headers != []
            headermatcher = newheadermatcher(headers)
            push!(matchers, headermatcher)
        end
        return new(handler, matchers, )
    end
end

function matchroute(route::Route, req::HTTP.Request)
    # match for all the matchers (conditions) set for this route
    for m in route.matchers
        if !(matchroute(m, req))
            return false
        end
    end
    return true
end

#######################################
#            Matchers
#######################################

############### Path or host matcher ###########

mutable struct Regexpmatcher <: Matcher
    template::String
    matchhost::Bool
    hardcorded::Array{String}
    varnames::Array{String}
    regexp::Regex

    function Regexpmatcher(p::String, cond::String)
        template = p
        idxs = braces_indexes(p)
        # TODO: take care of endslash case
        defregexp = "[^/]+"
        if cond == "host"
            defregexp = "[^.]+"
        end
        pattern = "^"
        iend = 1
        varsn = []
        for i in 1:2:length(idxs)
            staticsegment = p[iend:idxs[i]-1]
            iend = idxs[i+1]
            parts = split(p[idxs[i]+1:iend-2], ":")
            name = parts[1]
            tmpregexp = defregexp
            if length(parts) == 2
                tmpregexp = parts[2]
            end
            # build regexp here
            pattern = string(pattern, staticsegment, "(?P<", vargroupname(trunc(Int, i/2)), ">", tmpregexp, ")")
            push!(varsn, name)
        end

        staticsegment = p[iend:end]
        pattern = string(pattern, staticsegment, "\$")
        pattern = Regex(pattern)
        hardcorded = hardcordednames(p, cond)
        matchhost = cond == "host"
        return new(p, matchhost, hardcorded, varsn, pattern)
    end
end

function matchroute(regexpmatcher::Regexpmatcher, req::HTTP.Request)
    if regexpmatcher.matchhost == true
        s = HTTP.host(HTTP.uri(req))
        s = split(s, ":")[1]
    else
        s = HTTP.path(HTTP.uri(req))
    end
    return ismatch(regexpmatcher.regexp, s)
end

function newmatcher(tpl::String, cond::String)
    return Regexpmatcher(tpl, cond)
end

############# Method matcher ###########
struct Methodmatcher <: Matcher
    methods::Array{String}
end

function newmethodmatcher(methods::Array{String})
    for (i, v) in enumerate(methods)
        methods[i] = uppercase(methods[i])
    end
    return Methodmatcher(methods)
end

function matchroute(methodmatcher::Methodmatcher, req::HTTP.Request)
    reqmtd = string(HTTP.method(req))
    return (reqmtd in methodmatcher.methods)
end

############ Header matcher ################
struct Headermatcher <: Matcher
    headermap::Dict{String, String}
    function Headermatcher(headers)
        #if length(headers)%2 != 0 TODO: Log error when there are odd number of arguments
        headermap = Dict{String, String}()
        for i in 1:2:length(headers)
            headermap[headers[i]] = headers[i+1]
        end
        return new(headermap)
    end
end

function matchroute(m::Headermatcher, req)
    reqheaders = HTTP.headers(req)
    for (k,v) in m.headermap
        if haskey(reqheaders, k)
            if !(reqheaders[k] == v || v == "")
                return false
            end
        else
            return false
        end
    end
    return true
end

function newheadermatcher(headers)
    return Headermatcher(headers)
end

######### util functions ##########

# populates the values of the variables from the path
function setvarnames(m::Regexpmatcher, req)
    if m.matchhost == true
        host = HTTP.hostname(HTTP.uri(req))
        return extractvarvalues(host, m, "host")
    else
        path = HTTP.path(HTTP.uri(req))
        return extractvarvalues(path, m, "path")
    end
end

# util function to get the indexs of the {} braces
function braces_indexes(path::String) #TODO add error checking for unbalanced braces
    idxs = []
    for (i, c) in enumerate(path)
        if c == '{'
            push!(idxs, i)
        elseif c == '}'
            push!(idxs, i+1)
        end
    end
    return idxs
end

# util function to get capturing group name for regular expression
function vargroupname(i::Int)
    return string("v", string(i))
end

function hardcordednames(tpl::String, cond::String)
    hardcorded = []
    if cond == "path"
        segments = split(tpl, "/")[2:end] # ignore "" (empty) segment
    elseif cond == "host"
        segments = split(tpl, ".")
    end

    for (i, seg) in enumerate(segments)
        if seg[1] != '{' && seg[end] != '}'
            push!(hardcorded, positionprefixname(seg, i))
        end
    end
    return hardcorded
end

function extractvarvalues(tpl::String, m::Regexpmatcher, cond::String)
    varvalues = Dict{String, Any}()
    hardcorded = m.hardcorded
    varnames = m.varnames
    if cond == "path"
        segments = split(tpl, "/")[2:end]
    else
        segments = split(tpl, ".")
    end
    k = 1

    if length(varnames) > 0
        for (i, seg) in enumerate(segments)
            if !(positionprefixname(seg, i) in hardcorded)
                varvalues[varnames[k]] = String(seg)
                k = k + 1
            end
        end
    end
    return varvalues
end

function positionprefixname(s::SubString, pos::Int)
    return string(pos, s)
end
