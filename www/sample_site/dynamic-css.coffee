
# This file demonstrates dynamically constructing CSS.

COLOR_CHOICES = [
    'red'
    'orange'
    'yellow'
    'green'
    'blue'
    'indigo'
    'violet'
]

color = _.sample(COLOR_CHOICES)

output_css = """
    h1, h2 {
        color: #{ color };
    }
"""

response.ok(output_css, headers={'Content-Type':'text/css'})
