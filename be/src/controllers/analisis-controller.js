const axios = require("axios");
const FormData = require("form-data");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient(); // Pastikan prisma client sudah diinisialisasi
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

      const userId = req.user?.id;

      if (userId) {
        await Promise.all(
          predictions.map(async (pred) => {
            await prisma.prediksi.create({
              data: {
                imageUrl: filePath,
                user_id: userId,
                kualitas: pred.grade,
                harga: pred.harga,
              },
            });
          })
        );
      }

      // Hapus file sementara
      fs.unlinkSync(filePath);

      res.json({ success: true, data: predictions });
    } catch (err) {
      console.error(err);
      res.status(500).json({ success: false, message: "Terjadi kesalahan" });
    }
  }
}

module.exports = PredictController;
