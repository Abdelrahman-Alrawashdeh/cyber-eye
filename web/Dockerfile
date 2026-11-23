FROM nginx:alpine

# Static frontend (login + dashboard + shared assets)
COPY ./frontend /usr/share/nginx/html

# Nginx: static files + /api reverse proxy to the Flask backend
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
