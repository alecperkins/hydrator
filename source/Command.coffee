

App     = require './App'
path    = require 'path'
fs      = require 'fs'

module.exports.run = ->
    command     = process.argv[2]
    app         = new App()

    switch command
        when 'serve'
            site_path = path.join(process.cwd(), 'www')
            package_file = path.join(process.cwd(), 'package.json')
            package_info = JSON.parse(fs.readFileSync(package_file).toString())
            app.serve(site_path, package_info)
