
# This file demonstrates returning JSON-serializable data.

response.ok
    title   : 'JSON-serializable data'
    params  : request.query
    path    : request.path
    date    : new Date()
    objects: [
        {
            foo: 'foo'
            id: '1234'
        }
        {
            bar: 'bar'
            id: '1235'
        }
    ]
