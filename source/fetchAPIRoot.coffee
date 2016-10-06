request_lib = require 'request'
cli = require 'cli'
pkg = require '../package.json'

module.exports = (cb) ->
    cli.spinner('Connecting to API...')
    request_lib.get
        uri: "https://rehydrator.herokuapp.com/__/api_root/"
        qs:
            version: pkg.version
    , (err, response) ->
        if err
            console.error('Unable to connect to API.')
            process.exit(1)
        cli.spinner('', true)
        cb(response.body)
