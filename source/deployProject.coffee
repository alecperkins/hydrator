archiver        = require 'archiver'
bcrypt          = require 'bcrypt'
cli             = require 'cli'
cli_config      = require './cli_config'
FormData        = require 'form-data'
fs              = require 'fs'
path            = require 'path'
pkg             = require '../package.json'
request_lib     = require 'request'
{ File }        = require './files'

USER_AGENT      = "#{ pkg.name }/#{ pkg.version }"
ONE_MB          = 1 * 1024 * 1024 # 1 MiB
MAX_FILE_SIZE   = ONE_MB
MAX_FILE_COUNT  = 20


abortWithError = (message) ->
    console.error(message)
    process.exit(1)

humanFileSize = (bytes, si=false) ->
    threshold = if si then 1000 else 1024
    if bytes < threshold
        return "#{ bytes } B"
    units = if si then ['KB','MB','GB','TB','PB','EB','ZB','YB'] else ['KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB']
    u = -1
    while bytes >= threshold
        bytes /= threshold
        u += 1
    return "#{ Math.ceil(bytes) } #{ units[u] }"

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


uploadProject = ({ project, deployment, options, config }) ->

    cli.spinner('Uploading project...')

    files = walkSync(project.path)

    if files.length > MAX_FILE_COUNT
        abortWithError("Too many files (#{ files.length }). Projects are limited to #{ MAX_FILE_COUNT } deployed files.")

    files.forEach (f) ->
        if f.stats.size > MAX_FILE_SIZE
            abortWithError("File too big (#{ f.name }, #{ humanFileSize(f.stats.size) }). Project files are limited to #{ humanFileSize(MAX_FILE_SIZE) } each.")

    archive = archiver.create('tar', gzip: true, gzipOptions: { level: 1 })

    deployment_intermediary_file = path.join(project.path, '.rehydrator.deployment.tgz')

    # Create a temporary file to store the deployment archive.
    # (Buffers were causing trouble with the multipart upload.)
    payload = fs.createWriteStream(deployment_intermediary_file)

    archive.pipe(payload)
    archive.on 'error', (err) -> throw err

    files.forEach (f) ->
        _f = new File
            path    : f.local_path
            content : fs.readFileSync(f.local_path)
        
        compiled = _f.compile(minify: true)

        remote_path = compiled.path.replace(project.path, '')
        if remote_path isnt '/'
            remote_path = "/#{ remote_path }"

        archive.append(compiled.content, name: remote_path)

    payload.on 'close', ->
        _url = "#{ options.API_ROOT }deployments/"
        request_lib.post
            uri     : _url
            json    : true
            headers :
                'User-Agent': USER_AGENT
                'x-api-key': config.api_key
            body: {
                host            : deployment.host
                owner_secret    : deployment.owner_secret
            }
        , (err, response, body) ->
            if err
                cli.spinner('', true)
                console.error('There was a problem uploading the project. (API)')
                process.exit(1)

            {
                upload_url
                upload_form
            } = response.body

            # This happens when the host has been deleted from S3 but not from .rehydrator.json.
            unless upload_url
                cli.spinner('', true)
                console.error('\nThere was a problem uploading the project. (Most likely the specified host no longer exists. Try removing it from .rehydrator.json and trying again.)')
                process.exit(1)

            form_req = request_lib.post
                uri: upload_url
                headers:
                    'User-Agent': USER_AGENT
            , (err, _res) ->
                if err
                    cli.spinner('', true)
                    console.error(err)
                    console.error('There was a problem uploading the project. (S3)')
                    process.exit(1)
                fs.unlinkSync(deployment_intermediary_file)
                # Wait for the processDeployment worker to do its thing.
                setTimeout ->
                    cli.spinner('Uploading project...done!', true)
                    console.log("""\n
                        Project successfully uploaded to #{ deployment.host }
                        
                        (Please allow a moment for caching to update.)
                    """)
                , 2000

            _form = form_req.form()
            # Ensure the same key order.
            for field in ['key', 'acl', 'Content-Type', 'AWSAccessKeyId', 'policy', 'signature', 'x-amz-storage-class']
                _form.append(field, upload_form[field])

            _form.append('file', fs.createReadStream(deployment_intermediary_file), {
                filename: "#{ deployment.host }.tgz"
                contentType: 'application/octet-stream'
            })

    archive.finalize()



createHost = ({ host, email, API_ROOT, project_id, API_KEY }, callback) ->
    cli.spinner('Creating host...')

    owner_email_hash = bcrypt.hashSync(email, 12)

    request_lib.post
        uri     : API_ROOT + 'hosts/'
        json    : true
        body:
            host                : host
            owner_email_hash    : owner_email_hash
            project_id          : project_id
        headers:
            'User-Agent'    : USER_AGENT
            'x-api-key'     : API_KEY
    , (err, response, body) ->
        throw err if err
        if response.statusCode isnt 201
            if response.statusCode is 409
                abortWithError("The requested host `#{ host }` is unavailable. Try another one or use --auto.")
            abortWithError("There was a problem creating the host: #{ host }")

        body = response.body

        owner_secret    = body.owner_secret
        host            = body.host
        project_id      = body.project_id

        # Let the manifest settle. The API should only respond with host
        # create success after the manifest is ready, but give it a
        # second just to be sure.
        setTimeout ->
            cli.spinner('Creating host...done!', true)
            callback project_id,
                host            : host
                owner_secret    : owner_secret
                owner_email     : email
                version         : 0
                deployed_date   : null
        , 3000


module.exports = ({ project, options, config }) ->

    if options.host is 'localhost'
        options.host = null

    existing_deployment = null

    if project.deployments?.hosts
        prior_hosts = Object.keys(project.deployments.hosts)
        if prior_hosts.length > 0
            if prior_hosts.length > 1 and not (options.host or options.auto)
                abortWithError("""
                    --host (or --auto) argument required when multiple hosts already deployed.
                """)

            if options.host
                if options.host.split('.').length is 1
                    options.host = "#{ options.host }.rehydrated.coffee"
                existing_deployment = project.deployments.hosts[options.host]
            else if prior_hosts.length is 1 and not options.auto
                existing_deployment = project.deployments.hosts[prior_hosts[0]]

    if existing_deployment
        uploadProject
            project     : project
            deployment  : existing_deployment
            options     : options
            config      : config
    else
        if not (options.email or config.email)
            abortWithError """
                An email address is required the first time you deploy.

                --email user@example.com
            """

        if options.email and not config.email
            config.email = options.email
            cli_config.set('email', options.email)

        createHost
            project_id: project.deployments?.id
            host: options.host
            email: options.email or config.email
            API_ROOT: options.API_ROOT
            API_KEY: config.api_key
        , (project_id, host_info) ->

            project.deployments ?=
                hosts: {}
                project_id: project_id
            project.deployments.hosts[host_info.host] = host_info

            # Save the host info now in case there's a problem
            # parsing and uploading the project.
            fs.writeFileSync(
                project.deployments_file_path
                JSON.stringify(project.deployments, null, 4)
            )

            uploadProject
                project     : project
                deployment  : host_info
                options     : options
                config      : config
