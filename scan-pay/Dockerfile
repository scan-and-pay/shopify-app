FROM node:20-alpine
RUN apk add --no-cache openssl

# Expose port 8080 for compatibility with common reverse proxy configs
EXPOSE 8080

WORKDIR /app

ENV NODE_ENV=production
# Set PORT to 8080 to match EXPOSE
ENV PORT=8080

COPY package.json package-lock.json* ./

RUN npm ci --omit=dev && npm cache clean --force

COPY . .

RUN npm run build

CMD ["npm", "run", "docker-start"]
