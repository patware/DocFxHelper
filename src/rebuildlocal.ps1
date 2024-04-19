set-location $PSScriptRoot

& docker build -f publisher.dockerfile -t publisher:local .
& docker build -f site.dockerfile -t site:local .
