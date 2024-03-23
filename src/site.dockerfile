# syntax=docker/dockerfile:1

# build: docker build -f .\site.dockerfile -t site:local .
# run:   docker run -it -d --volume d:\rnd\docker\docfxHelper\virtualVolume\site\:/usr/share/nginx/html/ -p 8083:80 -e "NGINX_PORT=80" site:local
FROM nginx:latest

# Nginx image has a function that reads template files in /etc/nginx/templates/*.template and outputs 
#   the result of executing envsubst to /etc/nginx/conf.d.
#      From: /etc/nginx/templates/default.conf.template 
#        To: /etc/nginx/conf.d/default.conf
# VOLUME MOUNT DocFx static assets into /usr/share/nginx/html
#   Mount ./hocdocs/ /usr/share/nginx/html/
#   Index.html to index.html (Linux is case sensitive)
#       Nope... ./hocdocs/Index.html /usr/share/nginx/html/index.html
# Overwrite default nginx config
COPY ./default.conf.template /etc/nginx/templates/default.conf.template
ENV NGINX_HOST localhost
ENV NGINX_PORT 80
# EXPOSE 80 443
# EXPOSE 80