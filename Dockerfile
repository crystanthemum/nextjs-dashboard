# specify the node base image with your desired version node:<version>
FROM node:24
# replace this with your application's default port
WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

ENV PORT=8080

EXPOSE 8080

CMD ["npm", "start"]
