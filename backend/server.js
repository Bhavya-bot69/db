require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const app = express();
connectDB();

// adjust origin to your React dev server (http://localhost:3000) or set true for dev
app.use(cors({ origin: 'http://localhost:3000', credentials: true }));
app.use(express.json());

// routes
app.use('/api/auth', require('./routes/auth'));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server listening on ${PORT}`));
