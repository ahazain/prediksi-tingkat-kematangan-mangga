const express = require("express");

const route = express.Router();
const PredictController = require("../controllers/analisis-controller");
const multer = require("../middleware/multer");
route.post("/", multer.single("image"), PredictController.predict);

module.exports = route;
