http    = require 'http'
url     = require 'url'
util    = require 'util'
path    = require 'path'

Site    = require './Site'

PORT    = process.env.PORT or 5000



class App
    constructor: ->
        @_config = {}
        @_sites = {}

    serve: (site_path, package_data) ->
        if package_data.hydrator?.sites?
            @_config.multi = true
            for h, p of package_data.hydrator.sites
                @_sites[h] = new Site(path.join(site_path, p))
            @_server = http.createServer(@_handleRequest)
        else
            @_config.multi = false
            @_default_site = new Site(site_path)
        @_server = http.createServer(@_handleRequest)
        util.log("Server listening on http://localhost:#{ PORT }")
        @_server.listen(PORT)

    _handleRequest: (req, res) =>
        request_host = req.headers.host.split('.')
        if request_host[0] is 'www'
            request_host.shift()
        request_host = request_host.join('.')
        site = @_sites[request_host] or @_default_site

        unless site?
            util.log("#{ req.method } #{ req.headers.host }#{ req.url } - 404")
            res.writeHead(404)
            res.end('404 No Such App')
        else
            req.parsed_url = url.parse(req.url, true)

            # Get the file referred to by the request path.
            req.parsed_url.path_components = req.parsed_url.pathname.split('/').filter (c) -> c.length > 0
            target_file = site.getTargetFile(req.parsed_url.path_components)

            if target_file
                util.log("#{ req.method } #{ req.headers.host }#{ req.url } - #{ target_file.path }")
                target_file.respond(req, res)
            else
                util.log("#{ req.method } #{ req.headers.host }#{ req.url } - 404")
                res.writeHead(404)
                res.end('404 Not Found')



module.exports = App
