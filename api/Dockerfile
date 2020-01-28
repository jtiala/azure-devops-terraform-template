FROM node:13-alpine

# Copy source
WORKDIR /api
COPY . .

# Default NODE_ENV
ARG NODE_ENV=production

# Install dependencies
RUN if [ "$NODE_ENV" = "production" ]; then npm ci; else npm install; fi

# Expose ports
EXPOSE 80

# Start the app
CMD npm start
