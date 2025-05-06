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

async function testDatabaseConnection() {
  try {
    const connection = await mysql.createConnection(dbConfig);
    await connection.query('SELECT 1');
    await connection.end();
    console.log('Database connection successful');
    return true;
  } catch (error) {
    console.error('Database connection failed:', error.message);
    return false;
  }
}

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
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    console.error('Server startup failed: Could not connect to database');
    process.exit(1);
  }
  
  app.listen(port, () => {
    console.log(`App running on http://localhost:${port}`);
  });
}

startServer();
