from ultralytics import YOLO
import cv2

# Load model hasil training (ubah path sesuai lokasi file .pt kamu)
model = YOLO("best.pt")  # Ganti path ini

# Buka webcam (0 untuk kamera default)
cap = cv2.VideoCapture(0)

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    # Prediksi objek di frame
    results = model.predict(source=frame, conf=0.3)

    # Ambil frame yang sudah ada bounding box
    annotated_frame = results[0].plot()

    # Tampilkan ke layar
    cv2.imshow("Deteksi Real-Time", annotated_frame)

    # Tekan 'q' untuk keluar
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
