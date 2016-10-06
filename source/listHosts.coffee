module.exports = ({ project, options }) ->
    hosts = project.deployments?.hosts or {}
    hosts = Object.keys(hosts)
    if hosts.length is 0
        console.log('Project is not deployed to any hosts.')
    else
        console.log("""Project is deployed to:
            * #{ hosts.join('\n* ') }
        """)