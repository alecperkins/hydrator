http    = require 'http'
util    = require 'util'
url     = require 'url'
path    = require 'path'
fs      = require 'fs'
mime    = require 'mime'
pkg     = require '../package.json'
{ mapURLToSource } = require './paths'
{ File } = require './files'
anyBody = require 'body/any'
sandbox = require './sandbox'

parseBody = (request, response, callback) ->
    if request.method in ['POST', 'PUT']
        anyBody request, response, (err, body) ->
            if err
                console.error(err)
                response.writeHead 500,
                    'Content-Type': 'text/plain'
                response.end("""
                    500: Internal Server Error

                    #{ err.message }

                    #{ err.stack }
                """)
                return
            callback(body)
    else
        callback({})

module.exports = ({ project, options }) ->

    route = (request, response) ->

        parsed_url = url.parse(request.url, true)
        pathname = parsed_url.pathname

        # Add trailing slashes to requests.
        if pathname.split('/').pop().split('.').length is 1 and pathname[pathname.length - 1] isnt '/'
            response.writeHead 302,
                'Location': "#{ pathname }/"
            response.end()
            console.log("(302) [#{ request.method }] #{ request.url }")
            return

        possible_source_files = mapURLToSource(pathname)

        target_file = null
        for f in possible_source_files
            file_abs_path = path.join(project.path, f)
            if fs.existsSync(file_abs_path)
                target_file = file_abs_path
                break

        unless target_file
            response.writeHead 404,
                'Content-Type': 'text/plain'
            response.end('404: Not Found')
            console.log("(404) [#{ request.method }] #{ request.url }")
            return

        file = new File
            path: target_file
            content: fs.readFileSync(target_file)

        compiled = file.compile(minify: options.production)

        if compiled.is_executable

            parseBody request, response, (req_body) ->
                sandbox.executeFile(
                    project: project
                    request:
                        url         : request.url
                        pathname    : parsed_url.pathname
                        query       : parsed_url.query
                        host        : request.headers.host
                        body        : req_body
                        method      : request.method
                        headers     : request.headers
                    file_to_execute: compiled.content
                ).then ({ code, body, headers }) ->
                    response.writeHead(code, headers)
                    response.end(body)

                .catch (err) ->
                    console.error(err)
                    response.writeHead 500,
                        'Content-Type': 'text/plain'
                    response.end("""
                        500: Internal Server Error

                        #{ err.message }

                        #{ err.stack }
                    """)

            return

        response.writeHead 200,
            'Content-Type': mime.lookup(compiled.path)
            'Last-Modified': (new Date()).toString()
            'X-Hydrator-Version': pkg.version
        response.end(compiled.content)
        console.log("(200) [#{ request.method }] #{ request.url }")

        return

    HOST = options.host
    PORT = options.port
    http.createServer(route).listen(PORT, HOST)
    util.log("Server listening at http://#{ HOST }:#{ PORT }")
