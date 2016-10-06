

request_lib     = require 'request'
fetchAPIRoot    = require './fetchAPIRoot'
cli_config      = require './cli_config'
cli             = require 'cli'
module.exports = ({ key, options }) ->

    unless key
        console.error('Missing <key> argument: `hydrator auth <key>`')
        process.exit(1)

    cli.spinner('Setting key...')

    fetchAPIRoot (api_root) ->

        # Validate the key against the API.
        request_lib
            method  : 'OPTIONS'
            uri     : api_root
            json    : true
            headers:
                'x-api-key': key
        , (err, response) ->

            cli.spinner('', true)

            if err
                console.error('Unable to verify key.')
                process.exit(1)

            if response.body?.message is 'Forbidden'
                console.error('Invalid key.')
                process.exit(1)

            # Key is valid! Great success.

            cli_config.set('api_key', key)

            cli.spinner('Setting key...done!', true)