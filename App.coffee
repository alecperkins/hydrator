
path            = require 'path'
fs              = require 'fs'
mime            = require 'mime'
CoffeeScript    = require 'coffee-script'
vm              = require 'vm'
marked          = require 'marked'
restler         = require 'restler'
_               = require 'underscore'

_compile = (data, ext) ->
    switch ext
        when 'coffee'
            return [
                CoffeeScript.compile(data.toString())
                'application/javascript'
            ]
        when 'md'
            return [
                marked(data.toString())
                'text/html'
            ]
    return ''



_isCompilable = (p) -> p.split('.').pop() in ['coffee', 'md']
_isCompileTo = (p) -> p.split('.').pop() in ['js']



class File
    executable: false

    constructor: (components...) ->
        @path = path.join(components...)
        @_is_compilable = _isCompilable(components[components.length - 1])

    exists: -> fs.existsSync(@path)

    respond: ({ req, res, path_components, req_url }) ->
        fs.readFile @path, (err, data) =>
            throw err if err?
            if @_is_compilable
                [data, content_type] = _compile(data, @path.split('.').pop())
            else
                content_type = mime.lookup(@path)
            res.writeHead 200,
                'Content-Type': content_type
            res.end(data)

    setRoot: (root) ->
        @path = path.join(root, @path)
        return this



vmRequire = (path, sandbox, res) ->
    fs.readFile require.resolve(path), (err, code) ->
        code = CoffeeScript.compile(code.toString())
        try
            vm.runInNewContext(code, sandbox)
        catch e
            res.writeHead(500)
            res.end('500 Server Error')



class ExecutableFile extends File
    executable: true

    constructor: (component) ->
        @path = "#{ component }.coffee"

    respond: ({ req, res, path_components, req_url }) ->

        _sendResponse = (code, data='', headers={}) ->
            if not data.charAt?
                data = JSON.stringify(data)
                content_type = 'application/json'
            else
                content_type = 'text/html'
            headers['Content-Type'] ?= content_type
            headers['Content-Length'] ?= data.length
            res.writeHead(code, headers)
            res.end(data)
            return

        vmRequire "./#{ @path }",
            console : console
            env     : process.env
            restler : restler
            _       : _
            request:
                url             : req.url
                path            : path_components
                path_string     : req_url.pathname
                query           : req_url.query
                query_string    : req_url.search
                host            : req.headers.host
                method          : req.method
                headers         : req.headers
            response:
                # (data, headers={})
                ok                  : -> _sendResponse(200, arguments...)
                created             : -> _sendResponse(201, arguments...)
                noContent           : -> _sendResponse(204, arguments...)
                permanentRedirect: (data, headers={}) ->
                    headers['Location'] = data
                    _sendResponse(301, '', headers)
                temporaryRedirect: (data, headers={}) ->
                    headers['Location'] = data
                    _sendResponse(302, '', headers)
                badRequest          : -> _sendResponse(400, arguments...)
                unauthorized        : -> _sendResponse(401, arguments...)
                forbidden           : -> _sendResponse(403, arguments...)
                notFound            : -> _sendResponse(404, arguments...)
                methodNotAllowed    : -> _sendResponse(405, arguments...)
                gone                : -> _sendResponse(410, arguments...)
                internalServerError : -> _sendResponse(500, arguments...)
        , res



module.exports.getTargetFilePaths = (path_components) ->
    # Request is to /
    if path_components.length is 0
        return [
            new ExecutableFile('index')
            new File('index.html')
            new File('index.md')
            new ExecutableFile('*')
        ]

    # If any of the path components start with an underscore,
    # consider the path private and return no files.
    for c in path_components
        if c[0] is '_'
            return []

    # Request is to /<component>/ or /<file>.<ext>
    if path_components.length is 1

        component = path_components[0].split('.')

        # Request is to /<component>/
        if component.length is 1
            return [
                new ExecutableFile(path_components[0])
                new File(path_components..., 'index.html')
                new File(path_components..., 'index.md')
                new File(component[0] + '.md')
                new File(path_components...)
                new ExecutableFile('*')
            ]

        # Direct linking to root coffee files it not permitted,
        # so return an empty file list.
        if component[component.length - 1] is 'coffee'
            return []

        # Request is to /<file>.<ext>
        paths = [
            new File(path_components...)
        ]
        # /<file>.html
        if component[component.length - 1] is 'html'
            alt_version = [
                [component[...-1]..., 'md'].join('.')
            ]
            paths.push(new File(alt_version...))
        paths.push(new ExecutableFile('*'))
        return paths

    # Request is to /<component>/<component>...
    last_c = path_components[path_components.length - 1].split('.')

    # Request is to /**/<component>/
    if last_c.length is 1
        return [
            new ExecutableFile(path_components[0])
            new File(path_components..., 'index.html')
            new File(path_components..., 'index.md')
            new File(path_components[0...-1]..., last_c[0] + '.md')
            new File(path_components...)
            new ExecutableFile('*')
        ]

    # Request is to /**/<file>.<ext>
    paths = [
        new File(path_components...)
    ]
    # It's possibly the output of a compilable file, so include the possible
    # source file.
    if last_c[last_c.length - 1] is 'js'
        alt_version = [
            path_components[...- 1]...
            [last_c[...-1]..., 'coffee'].join('.')
        ]
        paths.push(new File(alt_version...))
    else if last_c[last_c.length - 1] is 'html'
        alt_version = [
            path_components[...- 1]...
            [last_c[...-1]..., 'md'].join('.')
        ]
        paths.push(new File(alt_version...))
    paths.push(new ExecutableFile('*'))
    return paths
