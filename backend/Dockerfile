FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nestjs && adduser --system --uid 1001 nestjs

COPY --from=deps /app/package.json /app/package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder --chown=nestjs:nestjs /app/dist ./dist

USER nestjs
EXPOSE 3000
ENV PORT=3000

CMD ["node", "dist/main.js"]
