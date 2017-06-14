using Endpoints, Base.Test, HTTP

include("json2.jl")

Endpoints.@GET "/just/resource" ()->"testing just resource"
Endpoints.@GET "http://www.google.com/domain/and/resource" ()->"testing scheme and domain routing"
Endpoints.@GET "www.google.com/just/domain" ()->"testing just domain routing"

HTTP.serve(handler = Endpoints.handler)
