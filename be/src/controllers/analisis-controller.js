const axios = require("axios");
const FormData = require("form-data");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const fs = require("fs");
const path = require("path");

class PredictController {
  static async predict(req, res) {
    try {
      const filePath = req.file.path;

      const form = new FormData();
      form.append("image", fs.createReadStream(filePath));

      const flaskRes = await axios.post("http://localhost:5000/predict", form, {
        headers: form.getHeaders(),
      });

      const predictions = flaskRes.data;

      if (predictions.success && predictions.detections) {
        await Promise.all(
          predictions.detections.map(async (detection) => {
            await prisma.analisis.create({
              data: {
                imageUrl: filePath,
                tingkat_kematangan: detection.ripeness_level,
              },
            });
          })
        );
      }

      res.json({ success: true, data: predictions });
    } catch (err) {
      console.error(err);
      res.status(500).json({ success: false, message: "Terjadi kesalahan" });
    }
  }
}

module.exports = PredictController;
