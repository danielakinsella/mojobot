FROM --platform=linux/arm64 node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src

RUN npm run build
RUN npm prune --production

EXPOSE 8080

CMD ["node", "dist/index.js"]
