FROM python:3.11-slim

# Install system dependencies untuk OpenCV & PyTorch
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Konfigurasi user non-root UID 1000 sesuai standar Hugging Face Spaces
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Install dependencies Python (versi CPU hemat memori)
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir "numpy<2" && \
    pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy seluruh source code backend & model YOLO
COPY --chown=user . .

# Buat direktori temp jika belum ada
RUN mkdir -p temp

# Hugging Face Spaces me-route traffic ke port 7860
EXPOSE 7860

# Jalankan server dengan Gunicorn
CMD ["gunicorn", "-b", "0.0.0.0:7860", "--timeout", "120", "--workers", "1", "app:app"]
