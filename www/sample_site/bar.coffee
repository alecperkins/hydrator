
# This file demonstrates returning a string of markup, and performing an
# asynchronous action first.

asset = _.random(3,5)

restler.get('http://date.jsontest.com/').on 'complete', (res) ->

    response.ok """
        <link rel="stylesheet" href="/style.css">
        <link rel="stylesheet" href="/assets/style.css">
        <p>
            Oh hai, <code>#{ request.url }</code>
        </p>

        <p>
            The time according to <a href="http://jsontest.com">jsontest.com</a>
            is <code>#{ res.time }</code>.
        </p>

        <p>And now, a randomly selected kitten:</p>
        <img src="http://placekitten.com/#{ asset }00/300/">
    """
