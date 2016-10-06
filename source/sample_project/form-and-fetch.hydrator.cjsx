###
React can be used to 
###

Form = (props) ->
    <form method='POST' action=''>
        <input
            type        = 'text'
            value       = props.url
            name        = 'url'
            placeholder = 'http://example.com'
        />
        <button>Submit</button>
    </form>


Page = React.createClass

    getDefaultProps: -> {
        title   : 'Some React Project'
        shares  : 0
    }

    render: ->
        <html>
            <head>
                <meta charSet='utf-8' />
            </head>
            <body style={
                maxWidth: 800
                margin: '0 auto'
            }>
                <Form url=@props.url />
                { @props.title } ({ @props.url }) has been shared { @props.shares } times on Facebook.
            </body>
        </html>


query = request.body.url or 'http://example.com'

http.getJSON("https://graph.facebook.com/?id=#{ query }")
    .then (res) ->
        response.ok(<Page
            title   = res.og_object?.title
            shares  = res.share?.share_count
            url     = query
        />)
    .catch(response.internalServerError)
