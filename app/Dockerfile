FROM node:18-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY index.js ./
RUN mkdir -p /app/logs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/ > /dev/null || exit 1
CMD ["node", "index.js"]
