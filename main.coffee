http            = require 'http'
fs              = require 'fs'
path            = require 'path'
sys             = require 'sys'
url             = require 'url'
CoffeeScript    = require 'coffee-script'




{ getTargetFilePaths } = require './App.coffee'


# Load site mappings
sites =
    # 'example.com'             : 'folder_name'
    'localhost:5000'            : 'sample_site' # for development
    'app-hydra.herokuapp.com'   : 'sample_site'

server = http.createServer (req, res) ->

    # Match host to site root folder
    request_host = req.headers.host.split('.')
    if request_host[0] is 'www'
        request_host.shift()
    request_host = request_host.join('.')
    site_root = sites[request_host]

    req_url = url.parse(req.url, true)

    unless site_root?
        res.writeHead(404)
        res.end('404 No app')
        end_status = 404

    # Redirect to trailing slashes
    else if req_url.pathname.indexOf('.') is -1 and req_url.pathname[req_url.pathname.length - 1] isnt '/'
        res.writeHead 301,
            Location: req_url.pathname + '/' + req_url.search
        res.end()
        end_status = 301

    # Handle request
    else
        site_root = path.join('www', site_root)

        # Get possible files
        path_components = req_url.pathname.split('/').filter (c) -> c.length > 0
        target_files = getTargetFilePaths(path_components).map (f) -> f.setRoot(site_root)

        # Find the first file that exists
        target_file = null
        for f in target_files
            if f.exists()
                target_file = f
                break

        # No suitable files match the request path.
        unless target_file
            res.writeHead(404)
            res.end('404 Not Found')
            end_status = 404
        else
            end_status = target_file.respond
                req: req
                res: res
                path_components: path_components
                req_url: req_url

PORT = process.env.PORT or 5000
console.log 'Server listening on port', PORT
server.listen(PORT)
