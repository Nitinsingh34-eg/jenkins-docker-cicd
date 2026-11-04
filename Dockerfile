FROM nginx:alpine

COPY project/ /usr/share/nginx/html/

EXPOSE 80
