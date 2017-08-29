using Base.Test, Routing, HTTP

@testset "Routing" begin

function f(req, res)
    return HTTP.Response(200)
end

function mathstest(req, res)
    var = Routing.Vars
    body = string(var["subject"], " ", var["sem"])
    return HTTP.Response(body)
end

function phytest(req, res)
    var = Routing.Vars
    body = string(var["subject"], " ", var["sem"])
    return HTTP.Response(body)
end

function subdomainvalue(req, res)
    var = Routing.Vars
    body = string(var["subdomain"])
    return HTTP.Response(body)
end

r = Routing.Router()

# Test for path HTTP.
# The order of register defines the priorit of matching if there are more than
# one match. So HTTP with more specific conditions should be registered
# above than others.
Routing.register!(r, ((req, res) -> HTTP.Response(205)); path="/test/{subject}")
Routing.register!(r, mathstest; path="/test/{subject}/sem/{sem:[1-3]+}")
Routing.register!(r, phytest; path="/test/{subject}/sem/{sem}")
Routing.register!(r, ((req, res) -> HTTP.Response(206)); path="/test", headers=["Content-Type", "text/html; charset=utf-8"])
Routing.register!(r, ((req, res) -> HTTP.Response(207)); path="/test", headers=["Content-Type", ""])
Routing.register!(r, ((req, res) -> HTTP.Response(204)); path=nothing, methods=nothing, host="{subdomain:[a-b]+}.domain.com")
Routing.register!(r, subdomainvalue; path=nothing, methods=nothing, host="{subdomain:[x-z]+}.variablevalue.com")
Routing.register!(r, ((req, res) -> HTTP.Response(203)); path=nothing, methods=nothing, host="www.example.com")
Routing.register!(r, ((req, res) -> HTTP.Response(202)); path="/test", methods=["post"])
Routing.register!(r, ((req, res) -> HTTP.Response(200)); path="/test")

# simple path HTTP
req = HTTP.Request()
req.uri = HTTP.URI("/test")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(200)

# default matching, when nothing matches. By default default handler is 404
req = HTTP.Request()
req.uri = HTTP.URI("/default")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(404)

# default handler can be set explicitly
Routing.setdefaulthandler(r, ((req, res) -> HTTP.Response(201)))
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(201)

# test for variable paths
req = HTTP.Request()
req.uri = HTTP.URI("/test/maths")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(205)

# test for the value extraction from the path variables
req = HTTP.Request()
req.uri = HTTP.URI("/test/maths/sem/7")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response("maths 7")

# test for regular expression, only matches if sem value is 1-3
req = HTTP.Request()
req.uri = HTTP.URI("/test/phy/sem/3")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response("phy 3")

# test for method based routing
req = HTTP.Request()
req.uri = HTTP.URI("/test")
req.method = "POST"
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(202)

# test for host based routing
req = HTTP.Request()
req.uri = HTTP.URI(;path="/test", hostname="www.example.com")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(203)

# test for variable host routing
req = HTTP.Request()
req.uri = HTTP.URI(;path="/test", hostname="aaa.domain.com")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(204)

# test for variable values in host routing
req = HTTP.Request()
req.uri = HTTP.URI(;path="/test", hostname="xyz.variablevalue.com")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response("xyz")

# test for headers based routing
req = HTTP.Request()
req.uri = HTTP.URI("/test")
req.headers = HTTP.Headers("Content-Type" => "text/html; charset=utf-8")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(206)

# test for header based for the case when value for a key is empty in the registered route
req = HTTP.Request()
req.uri = HTTP.URI("/test")
req.headers = HTTP.Headers("Content-Type" => "random")
@test Routing.handle(r, req, HTTP.Response()) == HTTP.Response(207)
end
