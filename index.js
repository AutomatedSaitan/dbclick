const express = require('express');
const mysql = require('mysql2/promise');
const app = express();
const port = 3000;

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

const MAX_RETRIES = 5;
const RETRY_DELAY = 5000; // 5 seconds

async function testDatabaseConnection(retryCount = 0) {
  try {
    const connection = await mysql.createConnection(dbConfig);
    await connection.query('SELECT 1');
    await connection.end();
    console.log('Database connection successful');
    return true;
  } catch (error) {
    console.error(`Database connection attempt ${retryCount + 1} failed:`, error.message);
    if (retryCount < MAX_RETRIES) {
      console.log(`Retrying in ${RETRY_DELAY / 1000} seconds...`);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return testDatabaseConnection(retryCount + 1);
    }
    return false;
  }
}

// Add root route for API instructions
app.get('/', (req, res) => {
  res.send(`
    <h1>Entries API Documentation</h1>
    <h2>Available Endpoints:</h2>
    <ul>
      <li><strong>GET /last-entry</strong> - Retrieves the most recent entry from the database</li>
      <li><strong>POST /add-entry</strong> - Adds a new entry with current timestamp and random string</li>
    </ul>
    <h2>Example Usage:</h2>
    <pre>
    # Get last entry
    curl http://localhost:${port}/last-entry

    # Add new entry
    curl -X POST http://localhost:${port}/add-entry
    </pre>
  `);
});

app.get('/last-entry', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute('SELECT * FROM entries ORDER BY id DESC LIMIT 1');
    await connection.end();
    res.json(rows[0] || {});
  } catch (error) {
    console.error('Error retrieving last entry:', error.message);
    res.status(500).json({ error: 'Database error: ' + error.message });
  }
});

app.post('/add-entry', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const randomString = Math.random().toString(36).substring(2, 15);
    const currentTime = new Date();
    await connection.execute('INSERT INTO entries (timestamp, random_string) VALUES (?, ?)', [currentTime, randomString]);
    await connection.end();
    res.send('Entry added');
  } catch (error) {
    console.error('Error adding entry:', error.message);
    res.status(500).json({ error: 'Database error: ' + error.message });
  }
});

async function startServer() {
  console.log('Testing database connection...');
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    console.error(`Server startup failed: Could not connect to database after ${MAX_RETRIES} attempts`);
    process.exit(1);
  }
  
  app.listen(port, () => {
    console.log(`App running on http://localhost:${port}`);
  });
}

startServer();
