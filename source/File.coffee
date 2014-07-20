path    = require 'path'
fs      = require 'fs'
mime    = require 'mime'


class File
    compilable: false
    executable: false

    constructor: (@_site, path_components...) ->
        @path       = path.join(path_components...)
        @full_path  = path.join(@_site.root, @path)

    exists: ->
        return fs.existsSync(@full_path)



class StaticFile extends File
    respond: (req, res) ->
        fs.readFile @full_path, (err, data) =>
            throw err if err?
            res.writeHead 200,
                'Content-Type': mime.lookup(@path)
            res.end(data)





CoffeeScript    = require 'coffee-script'
marked          = require 'marked'
Stylus          = require 'stylus'
Nib             = require 'nib'

class CompilableFile extends File
    compilable: true
    respond: (req, res) ->
        fs.readFile @full_path, (err, data) =>
            throw err if err?
            [data, content_type] = @_compile(data)
            res.writeHead 200,
                'Content-Type': content_type
            res.end(data)

    _compile: (file_data) ->
        switch @path.split('.').pop()
            when 'coffee'
                return [
                    CoffeeScript.compile(file_data.toString())
                    'application/javascript'
                ]
            when 'styl'
                # Not async, just bonkers.
                compiled_style = null
                Stylus(file_data.toString()).use(Nib()).render (err, data) ->
                    compiled_style = data
                return [
                    compiled_style
                    'text/css'
                ]
            when 'md'
                return [
                    marked(file_data.toString())
                    'text/html'
                ]
        return ''



string  = require 'string'
_       = require 'underscore'
restler = require 'restler'
vm      = require 'vm'

DEBUG = process.env.DEBUG

vmRequire = (path, sandbox, res) ->
    fs.readFile require.resolve(path), (err, code) ->
        code = CoffeeScript.compile(code.toString())
        try
            vm.runInNewContext(code, sandbox)
        catch e
            res.writeHead(500)
            res.end("500 Server Error: #{ if DEBUG then e.toString() else '' }")

class ExecutableFile extends File
    executable: true
    constructor: (site, component) ->
        @_site = site
        @path = "#{ component }.coffee"
        @full_path = path.join(@_site.root, @path)

    respond: (req, res, cache) ->

        _sendResponse = (code, data='', headers={}) ->
            if not data.charAt?
                data = JSON.stringify(data)
                content_type = 'application/json'
            else
                content_type = 'text/html'
            headers['Content-Type'] ?= content_type
            res.writeHead(code, headers)
            res.end(data)
            return

        # TODO: Optimize by pre-compiling (or caching compiling)
        vmRequire @full_path,
            console         : console
            require         : require
            Buffer          : Buffer
            _raw_request    : req
            _raw_response   : res
            readFile        : null # TODO: replace with an fs scoped to site folder
            readFileSync    : null
            _               : _
            string          : string
            marked          : marked
            cache:
                get: (key, cb) =>
                    cache.get(@_site.name, key, cb)
                set: (key, value) =>
                    cache.set(@_site.name, key, value)
            env             : process.env
            restler         : restler
            request:
                url             : req.url
                path            : req.parsed_url.components
                path_string     : req.parsed_url.pathname
                query           : req.parsed_url.query
                query_string    : req.parsed_url.search
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


module.exports =
    CompilableFile  : CompilableFile
    ExecutableFile  : ExecutableFile
    StaticFile      : StaticFile
