const express = require('express');
const { MongoClient } = require('mongodb');

const app = express();
const PORT = process.env.PORT || 3000;

// Build MongoDB URL from environment variables
const MONGO_HOST = process.env.MONGO_HOST || 'localhost';
const MONGO_PORT = process.env.MONGO_PORT || '27017';
const MONGO_DB = process.env.MONGO_DB || 'nodeapp';
const MONGO_USER = process.env.MONGO_USER;
const MONGO_PASSWORD = process.env.MONGO_PASSWORD;

let MONGO_URL;
if (MONGO_USER && MONGO_PASSWORD) {
  MONGO_URL = `mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}`;
} else {
  MONGO_URL = `mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}`;
}

console.log('MongoDB URL:', MONGO_URL.replace(/:[^:@]+@/, ':****@')); // Log URL with masked password

let db = null;
let visitCollection = null;

// Connect to MongoDB
MongoClient.connect(MONGO_URL)
  .then(client => {
    console.log('Connected to MongoDB');
    db = client.db();
    visitCollection = db.collection('visits');
  })
  .catch(err => {
    console.error('MongoDB connection failed:', err);
  });

// Middleware
app.use(express.json());

// Routes
app.get('/', async (req, res) => {
  let visitCount = 0;
  let mongoStatus = 'disconnected';
  
  if (visitCollection) {
    try {
      mongoStatus = 'connected';
      await visitCollection.insertOne({ 
        timestamp: new Date(),
        ip: req.ip 
      });
      visitCount = await visitCollection.countDocuments();
    } catch (err) {
      console.error('MongoDB error:', err);
    }
  }
  
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Node.js App</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .connected { background-color: #d4edda; color: #155724; }
        .disconnected { background-color: #f8d7da; color: #721c24; }
      </style>
    </head>
    <body>
      <h1>Node.js Application</h1>
      <div class="status ${mongoStatus === 'connected' ? 'connected' : 'disconnected'}">
        MongoDB Status: ${mongoStatus}
      </div>
      <p>Total Visits: ${visitCount}</p>
      <p>Your IP: ${req.ip}</p>
      <hr>
      <p>
        <a href="/api/status">API Status</a> | 
        <a href="/api/visits">Visit History</a>
      </p>
    </body>
    </html>
  `);
});

app.get('/api/status', (req, res) => {
  res.json({
    status: 'ok',
    mongodb: db ? 'connected' : 'disconnected',
    mongo_url: MONGO_URL,
    port: PORT,
    node_version: process.version
  });
});

app.get('/api/visits', async (req, res) => {
  if (!visitCollection) {
    return res.status(503).json({ error: 'MongoDB not connected' });
  }
  
  try {
    const visits = await visitCollection
      .find()
      .sort({ timestamp: -1 })
      .limit(10)
      .toArray();
    res.json(visits);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});