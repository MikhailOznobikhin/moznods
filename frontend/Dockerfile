FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY . .

EXPOSE 5173

CMD ["sh", "-c", "if [ ! -d node_modules ] || [ -z \"$(ls -A node_modules)\" ]; then npm ci || npm install; fi; npm run dev -- --host"]
