path = require 'path'
fs = require 'fs'

createProject   = require './createProject'
serveProject    = require './serveProject'
deployProject   = require './deployProject'
showProjectURLs = require './showProjectURLs'
destroyProject  = require './destroyProject'
listHosts       = require './listHosts'
setAuth         = require './setAuth'
cli_config      = require './cli_config'

CREATE  = 'create'
SERVE   = 'serve'
DEPLOY  = 'deploy'
URLS    = 'urls'
DESTROY = 'destroy'
HOSTS   = 'hosts'
AUTH    = 'auth'

COMMAND_MAP =
    "#{ CREATE }"   : createProject
    "#{ SERVE }"    : serveProject
    "#{ DEPLOY }"   : deployProject
    "#{ URLS }"     : showProjectURLs
    "#{ DESTROY }"  : destroyProject
    "#{ HOSTS }"    : listHosts
    "#{ AUTH }"     : setAuth

DEPLOYMENTS_FILE = '.rehydrator.json'

fetchAPIRoot = require './fetchAPIRoot'

module.exports = ({ command, args, options }) ->

    if command is AUTH
        key = args[0]
        COMMAND_MAP[command]({ key, options })
        return

    config = cli_config.get()

    target_rel_path = args[0] or '.'
    if target_rel_path[0] is '/'
        target_path = target_rel_path
    else
        target_path = path.join(process.cwd(), target_rel_path)

    project =
        path        : target_path
        rel_path    : target_rel_path

    if fs.existsSync(target_path)
        if command is CREATE
            console.error("Project already exists: #{ target_rel_path }")
            process.exit(1)

        deployments_file = path.join(target_path, DEPLOYMENTS_FILE)

        if fs.existsSync(deployments_file)
            project.deployments = JSON.parse(
                fs.readFileSync(deployments_file).toString()
            )
        project.deployments_file_path = deployments_file
    else if command isnt CREATE
        console.error("Project does not exist: #{ target_rel_path }")
        process.exit(1)

    _invokeCommand = ->
        COMMAND_MAP[command]({ project, options, config }) 

    if command in [DEPLOY, DESTROY]
        unless config.api_key
            console.error('API key required. Set using `hydrator auth <key>`.')
            process.exit(1)
        fetchAPIRoot (_url) ->
            options.API_ROOT = _url
            _invokeCommand()
    else
        _invokeCommand()


module.exports.COMMANDS = Object.keys(COMMAND_MAP)