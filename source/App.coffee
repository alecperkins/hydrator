http    = require 'http'
url     = require 'url'
util    = require 'util'

Site    = require './Site'

PORT    = process.env.PORT or 5000



class App
    constructor: ->
        @_config = {}

    serve: (site_path) ->
        @_config.multi = false
        @_site      = new Site(site_path)
        @_server    = http.createServer(@_handleRequest)
        util.log("Server listening on http://localhost:#{ PORT }")
        @_server.listen(PORT)

    _handleRequest: (req, res) =>
        req.parsed_url = url.parse(req.url, true)

        # Get the file referred to by the request path.
        req.parsed_url.path_components = req.parsed_url.pathname.split('/').filter (c) -> c.length > 0
        target_file = @_site.getTargetFile(req.parsed_url.path_components)

        if target_file
            util.log("#{ req.method } #{ req.url } - #{ target_file.path }")
            target_file.respond(req, res)
        else
            util.log("#{ req.method } #{ req.url } - 404")
            res.writeHead(404)
            res.end('404 Not Found')



module.exports = App
