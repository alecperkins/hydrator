request_lib = require 'request'

fs = require 'fs'
cli = require 'cli'

pkg = require '../package.json'
USER_AGENT = "#{ pkg.name }/#{ pkg.version }"
abortWithError = (message) ->
    console.error(message)
    process.exit(1)

# Destroy does not strongly guard against accidental action beside
# requiring the host to be specified since the project can be
# immediately redeployed with the same host.
module.exports = ({ project, options, config }) ->

    if options.host is 'localhost'
        delete options.host

    unless Object.keys(project.deployments.hosts).length > 0
        abortWithError("""
            Project not deployed.
        """)

    unless options.host
        abortWithError("""
            --host argument required for destroy.
        """)

    deployment = project.deployments.hosts[options.host]

    unless deployment
        abortWithError("""
            Project not deployed to specified host.
        """)

    cli.spinner('Destroying project host...')

    request_lib.delete
        uri: "#{ options.API_ROOT }hosts/"
        json: true
        headers:
            'User-Agent': USER_AGENT
            'x-api-key': config.api_key
        body:
            host: deployment.host
            owner_secret: deployment.owner_secret
    , (err, response, body) ->
        throw err if err
        unless response.body.deleted is deployment.host
            abortWithError("There was a problem destroying the specified host: `#{ deployment.host }`")
        delete project.deployments.hosts[deployment.host]
        fs.writeFileSync(
            project.deployments_file_path
            JSON.stringify(project.deployments, null, 4)
        )
        cli.spinner('Destroying project host...done!', true)