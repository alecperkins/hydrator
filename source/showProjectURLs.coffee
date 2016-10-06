{ mapSourceToURL } = require './paths'

fs = require 'fs'
path = require 'path'

# Using a synchronous version of walk for simplicity
walkSync = (dir, ignore=['_','.']) ->
    results = []
    list = fs.readdirSync(dir)
    for f in list
        unless f[0] in ignore or not ignore
            file = path.join(dir,f)
            stats = fs.statSync(file)
            if stats?.isDirectory()
                results.push(walkSync(file)...)
            else
                results.push({
                    local_path: file
                    name: f
                    stats: stats
                })
    return results

module.exports = ({ project, options }) ->

    col_1_length = 0
    files = []
    walkSync(project.path).forEach (f) ->
        f = f.local_path.replace(project.path, '')
        if f[0] isnt '/'
            f = "/#{ f }"
        if f.length > col_1_length
            col_1_length = f.length
        files.push(f)

    files.forEach (f) ->
        padding = (' ' for i in [0..col_1_length - f.length]).join('')
        console.log "#{ f }#{ padding }--> #{ mapSourceToURL(f) }"