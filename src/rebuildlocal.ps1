set-location $PSScriptRoot

& docker build -f publisher.dockerfile -t publisher:local .
& docker build -f docs.dockerfile -t docs:local .
