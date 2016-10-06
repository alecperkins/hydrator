fs                  = require 'fs'
os                  = require 'os'
path                = require 'path'

CLI_CONFIG_FILEPATH = path.join(os.homedir(), '.hydrator.rc.json')



_getConfig = (key=null) ->
    if fs.existsSync(CLI_CONFIG_FILEPATH)
        existing_rc = JSON.parse(
            fs.readFileSync(CLI_CONFIG_FILEPATH).toString()
        )
    else
        existing_rc = {}

    if key
        return existing_rc[key]
    return existing_rc

module.exports.get = _getConfig



module.exports.set = (args...) ->
    if arguments.length is 1
        _config = args[0]
    else
        _config = null
        key = args[0]
        value = args[1]

    existing_rc = _getConfig()

    if _config
        existing_rc = _config
    else
        existing_rc[key] = value

    fs.writeFileSync(
        CLI_CONFIG_FILEPATH,
        JSON.stringify(existing_rc, null, 4)
    )

    return existing_rc