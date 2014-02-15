
App     = require './App'
path    = require 'path'
fs      = require 'fs'

readJSON = (f) -> JSON.parse(fs.readFileSync(f).toString())

module.exports.run = ->
    command         = process.argv[2]
    target          = process.argv[3] or ''

    project_path    = path.join(process.cwd(), target)
    site_path       = path.join(project_path, 'www')
    package_file    = path.join(project_path, 'package.json')

    app             = new App(readJSON(path.join(__dirname,'..','package.json')))

    switch command
        when 'serve'
            package_info = readJSON(package_file)
            app.serve(site_path, package_info)
        when 'create'
            app.create(project_path, target)
