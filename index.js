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

app.get('/last-entry', async (req, res) => {
  try {
    const connection = await mysql.createConnection(dbConfig);
    const [rows] = await connection.execute('SELECT * FROM entries ORDER BY id DESC LIMIT 1');
    await connection.end();
    res.json(rows[0] || {});
  } catch (error) {
    res.status(500).send('Error retrieving last entry');
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
    res.status(500).send('Error adding entry');
  }
});

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});
