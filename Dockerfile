# Deliberately pinned to an old release so Renovate has an update to raise.
FROM node:20.0.0-alpine

WORKDIR /app
COPY package.json ./
CMD ["node", "--version"]
