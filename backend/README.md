# backend

NestJS API for example-react-app. See the [root README](../README.md) for
how this fits into the rest of the repo.

## Development

```bash
npm install
npm run start:dev   # http://localhost:3000, restarts on change
```

## Scripts

| Command             | Description                        |
| --------------------- | ------------------------------------ |
| `npm run start:dev`   | Dev server with watch mode          |
| `npm run build`       | Compile to `dist/`                  |
| `npm run start:prod`  | Run the compiled build              |
| `npm run lint`         | ESLint                              |
| `npm test`             | Unit tests (Jest)                   |
| `npm run test:e2e`     | End-to-end tests                    |
| `npm run test:cov`     | Test coverage                       |

## Health check

`GET /health` returns `{ "status": "ok" }` — this is what the ALB target
group in `../terraform`/`../cloudformation` polls.

## Runtime configuration

The ECS task definitions in `../terraform`/`../cloudformation` inject these
environment variables: `PORT`, `DOCUMENTDB_ENDPOINT`, `DOCUMENTDB_SECRET_ARN`,
`ORACLE_ENDPOINT`, `ORACLE_SECRET_ARN`, `REDIS_PRIMARY_ENDPOINT`,
`REDIS_SECRET_ARN`. The `*_SECRET_ARN` values point at Secrets Manager
entries holding the actual credentials/auth tokens — fetch them at runtime
via the AWS SDK rather than passing credentials as plaintext env vars.

## Docker

```bash
docker build -t backend .
docker run -p 3001:3000 backend
```

See `../docker-compose.yml` to run this alongside the frontend.
