FROM mcr.microsoft.com/playwright:v1.49.1-noble

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

COPY src ./src

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

USER pwuser

CMD ["node", "src/server.js"]
