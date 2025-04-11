const express = require('express');
const mongoose = require('mongoose');
const app = express();
app.use(express.json());

mongoose.connect(process.env.MONGO_URL)
  .then(() => console.log('Mongo connected'))
  .catch(err => console.error(err));

app.get('/', (req, res) => res.send('API is working!'));

app.listen(3000, () => console.log('Server on port 3000'));
