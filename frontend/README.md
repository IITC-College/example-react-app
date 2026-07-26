# frontend

Next.js (App Router, TypeScript) frontend for example-react-app. See the
[root README](../README.md) for how this fits into the rest of the repo.

## Development

```bash
npm install
npm run dev       # http://localhost:3000
```

## Scripts

| Command               | Description                             |
| ---------------------- | ----------------------------------------- |
| `npm run dev`           | Start the dev server                     |
| `npm run build`         | Production build (`output: standalone`)  |
| `npm start`             | Run the production build                 |
| `npm run lint`           | ESLint                                   |
| `npm test`               | Run tests once (Vitest)                  |
| `npm run test:watch`   | Run tests in watch mode                  |

## Health check

`GET /api/health` returns `{ "status": "ok" }` — this is what the ALB
target group in `../terraform`/`../cloudformation` polls.

## Docker

```bash
docker build -t frontend .
docker run -p 3000:3000 frontend
```

See `../docker-compose.yml` to run this alongside the backend.
