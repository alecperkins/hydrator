

App     = require './App'
path    = require 'path'


module.exports.run = ->
    command     = process.argv[2]
    app         = new App()

    switch command
        when 'serve'
            site_path = path.join(process.cwd(), 'www')
            app.serve(site_path)
