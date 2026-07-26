import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <h1>example-react-app</h1>
        <p>Next.js frontend. See /api/health for the health check endpoint.</p>
      </main>
    </div>
  );
}
