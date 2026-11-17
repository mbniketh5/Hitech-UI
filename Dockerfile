FROM nginx:latest

# Remove default Nginx welcome page
#RUN rm -rf /usr/share/nginx/html/*

# Copy custom website files
COPY index.html /usr/share/nginx/html/index.html
COPY style.css /usr/share/nginx/html/style.css

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

