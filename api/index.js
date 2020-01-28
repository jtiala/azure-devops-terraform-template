// DB
const mongoose = require("mongoose");
const dbConnectionString = process.env.DB_CONNECTION_STRING;
const dbName = process.env.DB_NAME;
const index = dbConnectionString.lastIndexOf("?");
const dbUrl =
  index > -1
    ? `${dbConnectionString.slice(0, index)}${dbName}${dbConnectionString.slice(
        index
      )}`
    : `${dbConnectionString}${dbName}`;

mongoose.connect(
  dbUrl,
  { useNewUrlParser: true, useUnifiedTopology: true },
  err => {
    if (err) {
      console.error(err);
      process.exit(1);
    }
  }
);

const visitSchema = new mongoose.Schema(
  { timestamp: Date },
  { collection: "visits", shardKey: { _id: 1 } }
);

const Visit = mongoose.model("Visit", visitSchema);

// API
const express = require("express");
const app = express();
const port = 80;

app.get("/", (req, res) => {
  const newVisit = new Visit({ timestamp: new Date() });
  newVisit.save();

  Visit.countDocuments((err, count) => {
    if (err) {
      console.error(err);
      res.status(500).send("DB Error");
    } else {
      res.send(`Total visits: ${count}`);
    }
  });
});

app.listen(port, () => console.log(`API listening on port ${port}!`));
