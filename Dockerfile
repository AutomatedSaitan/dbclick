FROM node:18-slim

WORKDIR /app

# Copy dependency files first
COPY package*.json ./
RUN npm ci

# Create non-root user
RUN groupadd -r nodejs && useradd -r -g nodejs nodejs
RUN chown -R nodejs:nodejs /app

# Copy rest of the application
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

EXPOSE 3000

CMD ["npm", "start"]
