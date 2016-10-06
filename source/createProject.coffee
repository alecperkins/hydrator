cli = require 'cli'
fs  = require 'fs'



module.exports = ({ project, options }) ->
    cli.spinner('Creating project...')
    fs.mkdirSync(project.path)
    # if options.sample
    cli.spinner('Creating project...done!', true)