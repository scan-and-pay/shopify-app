# Stage 1: Build the Flutter web app
FROM debian:bookworm-slim AS build-env

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl git wget unzip libglu1-mesa python3 && \
    apt-get clean

# Clone Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Enable web
RUN flutter config --enable-web
RUN flutter doctor -v

# Copy app files
WORKDIR /app
COPY . .

# --- NEW LINE HERE ---
# Create an empty .env file so the build doesn't crash on missing assets
RUN touch .env
# ---------------------

# Build the web app
RUN flutter build web

# Stage 2: Serve with Nginx
FROM nginx:1.21.1-alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]