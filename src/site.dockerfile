# syntax=docker/dockerfile:1

# build: 
#   docker build -f .\site.dockerfile -t site:local .
#   docker build -f .\site.dockerfile -t site:local --progress=plain .
# run:   
#   local: docker run -it -d -p 8083:80 -e "NGINX_PORT=80" site:local
#   local with docfx generated site: 
#          docker run -it -d -p 8083:80 -e "NGINX_PORT=80" --volume d:\rnd\docker\docfxHelper\virtualVolume\site\:/usr/share/nginx/html/ site:local 

ARG NGINX_IMAGE_VERSION=1.25.5
FROM nginx:${NGINX_IMAGE_VERSION}

LABEL version="0.0.2"
LABEL releasenotes="Parameterized FROM image tag"
LABEL image_reference="https://hub.docker.com/_/nginx"

# Nginx image has a function that reads template files in /etc/nginx/templates/*.template and outputs 
#   the result of executing envsubst to /etc/nginx/conf.d.
#      From: /etc/nginx/templates/default.conf.template 
#        To: /etc/nginx/conf.d/default.conf
# VOLUME MOUNT DocFx static assets into /usr/share/nginx/html
#   Mount ./hocdocs/ /usr/share/nginx/html/
#   Index.html to index.html (Linux is case sensitive)
#     ./hocdocs/Index.html /usr/share/nginx/html/index.html
# Overwrite default nginx config
COPY ./default.conf.template /etc/nginx/templates/default.conf.template
ENV NGINX_HOST localhost
ENV NGINX_PORT 80

# With SSL certificate
# EXPOSE 80 443

EXPOSE 80