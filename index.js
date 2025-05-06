const express = require('express');
const mysql = require('mysql2/promise');
const app = express();
const port = 3000;

// Add middleware configuration
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

const MAX_RETRIES = 5;
const RETRY_DELAY = 5000; // 5 seconds

async function testDatabaseConnection(retryCount = 0) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] Attempting database connection (attempt ${retryCount + 1}/${MAX_RETRIES + 1})`);
  console.log(`[${timestamp}] Connection details: host=${dbConfig.host}, user=${dbConfig.user}, database=${dbConfig.database}`);
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    await connection.query('SELECT 1');
    await connection.end();
    console.log(`[${timestamp}] ✓ Database connection successful`);
    console.log(`[${timestamp}] Connection state: closed`);
    return true;
  } catch (error) {
    console.error(`[${timestamp}] ✗ Database connection attempt ${retryCount + 1} failed:`);
    console.error(`[${timestamp}] Error code: ${error.code}`);
    console.error(`[${timestamp}] Error number: ${error.errno}`);
    console.error(`[${timestamp}] SQL state: ${error.sqlState}`);
    console.error(`[${timestamp}] Error message: ${error.message}`);
    
    if (retryCount < MAX_RETRIES) {
      console.log(`[${timestamp}] Retrying in ${RETRY_DELAY / 1000} seconds...`);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return testDatabaseConnection(retryCount + 1);
    }
    console.error(`[${timestamp}] ✗ Maximum retry attempts (${MAX_RETRIES}) reached. Giving up.`);
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
      <li><strong>GET /add-entry</strong> - Adds a new entry with current timestamp and random string</li>
    </ul>
    <h2>Example Usage:</h2>
    <pre>
    # Get last entry
    curl http://localhost:${port}/last-entry

    # Add new entry
    curl http://localhost:${port}/add-entry
    </pre>
  `);
});

// Add health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
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

app.get('/add-entry', async (req, res) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] Processing GET request to /add-entry`);
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    console.log(`[${timestamp}] Database connection established`);
    
    const randomString = Math.random().toString(36).substring(2, 15);
    const currentTime = new Date();
    
    console.log(`[${timestamp}] Inserting new entry with random string: ${randomString}`);
    const [result] = await connection.execute(
      'INSERT INTO entries (timestamp, random_string) VALUES (?, ?)',
      [currentTime, randomString]
    );
    
    await connection.end();
    console.log(`[${timestamp}] Entry added successfully. Insert ID: ${result.insertId}`);
    
    res.status(201).json({
      message: 'Entry added successfully',
      id: result.insertId,
      timestamp: currentTime,
      randomString: randomString
    });
  } catch (error) {
    console.error(`[${timestamp}] Error adding entry:`, error);
    res.status(500).json({
      error: 'Database error',
      message: error.message,
      code: error.code,
      state: error.sqlState,
      timestamp: timestamp
    });
  }
});

// Add error handling middleware
app.use((err, req, res, next) => {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] Unhandled error:`, err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    timestamp: timestamp,
    path: req.path
  });
});

// Add 404 handler
app.use((req, res) => {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] 404 Not Found: ${req.method} ${req.path}`);
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`,
    timestamp: timestamp
  });
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
