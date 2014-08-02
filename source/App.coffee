http    = require 'http'
url     = require 'url'
util    = require 'util'
path    = require 'path'
fs      = require 'fs'
memjs   = require 'memjs'

{ exec } = require 'child_process'

Site    = require './Site'

PORT    = process.env.PORT or 5000


PROJECT_DEFAULTS =
    'package.json': (ctx) -> JSON.stringify({
            name        : ctx.name
            version     : '0.0.1'
            description : 'A Hydrator-powered app.'
            engines:
                node : '0.11.x'
                npm  : '~1.3.0'
            dependencies:
                hydrator: "~#{ ctx.hydrator_version }"
        }, 4)
    '.gitignore': (ctx) -> 'node_modules\n.env\n.DS_Store'
    '.env': (ctx) -> ''
    'Procfile': (ctx) -> 'web: ./node_modules/.bin/hydrator serve'
    'README.md': (ctx) -> """#{ ctx.name }
            #{ ('=' for i in [0...ctx.name.length]).join('') }\n
        """

PROJECT_DEFAULTS[path.join('www','index.coffee')] = (ctx) -> """
            response.ok("<h1>Hello, world!</h1><p>\#{ new Date() }</p>")
        """


getCacheServerURI = ->
    server_uri = null
    password = process.env.MEMCACHIER_PASSWORD
    servers = process.env.MEMCACHIER_SERVERS
    username = process.env.MEMCACHIER_USERNAME
    if username and password and servers
        server_uri = servers.split(',').map (s) -> "#{ username }:#{ password }@#{ s }"
        server_uri = server_uri.join(',')
    return server_uri

class TenantCache
    constructor: ->
        server_uri = getCacheServerURI()
        if server_uri
            @_cache = memjs.Client.create(server_uri, expires: 240) # 240 seconds
    get: (site, key, callback) ->
        unless site and key and @_cache
            callback(null)
            return
        _key = "#{ site }:#{ key }"
        @_cache.get _key, (err, val) ->
            if err
                console.log(err)
                callback(null)
            else
                val = val?.toString() or null
                if val
                    val = JSON.parse(val)
                callback(val)
        return
    set: (site, key, value, expires=240) ->
        unless site and key and value and @_cache
            return

        # Restrict expiration to between 1 second and 1 hour, inclusive.
        expires = Number(expires)
        unless expires and 1 <= expires <= 3600
            expires = 240
        _key = "#{ site }:#{ key }"
        logErr = (err) ->
            console.log(err) if err
        @_cache.set(_key, JSON.stringify(value), logErr, expires)
        return



class App
    constructor: (hydrator_package) ->
        @_hydrator_package = hydrator_package
        @_config = {}
        @_sites = {}

    serve: (site_path, package_data) ->
        if package_data.hydrator?.sites?
            @_config.multi = true
            for h, p of package_data.hydrator.sites
                @_sites[h] = new Site(path.join(site_path, p), h)
            @_server = http.createServer(@_handleRequest)
        else
            @_config.multi = false
            @_default_site = new Site(site_path, 'default')

        @_cache = new TenantCache()
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
                target_file.respond(req, res, @_cache)
            else
                util.log("#{ req.method } #{ req.headers.host }#{ req.url } - 404")
                res.writeHead(404)
                res.end('404 Not Found')

    create: (project_path, target) ->
        if fs.existsSync(project_path)
            console.log("\n#{ target } already exists. Aborting...\n")
            process.exit(1)

        console.log("\nCreating project: #{ target }...\n")

        console.log("-> #{ target }#{ path.sep }")
        fs.mkdirSync(project_path)

        console.log("-> #{ path.join(target,'www') }#{ path.sep }")
        fs.mkdirSync(path.join(project_path, 'www'))

        for f_name, content_fn of PROJECT_DEFAULTS
            console.log("-> #{ path.join(target, f_name) }")
            fs.writeFileSync path.join(project_path, f_name), content_fn
                name                : target
                hydrator_version    : @_hydrator_package.version

        console.log('\nrunning: git init')
        exec 'git init', cwd: project_path, (error, stdout, stderr) ->
            throw error if error?
            console.log """\n
                    #{ stdout }

                    Project #{ target } created.
                    Start it with `hydrator serve #{ target }`\n
                """



module.exports = App
