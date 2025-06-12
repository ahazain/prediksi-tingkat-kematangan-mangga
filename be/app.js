require("dotenv").config();
const express = require("express");
const app = express();
const predic = require("./src/routes/analisis-route");

app.use(express.json());
app.use("/analisis", predic);
app.get("/", (req, res) => {
  res.send("Hello World!");
});

app.listen(3000, () => {
  console.log("LOPE YOU 3000");
});
