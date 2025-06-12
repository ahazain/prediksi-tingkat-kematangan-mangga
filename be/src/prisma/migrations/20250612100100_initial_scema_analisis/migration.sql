-- CreateEnum
CREATE TYPE "Grade" AS ENUM ('A', 'B', 'C');

-- CreateTable
CREATE TABLE "Analisis" (
    "id" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "tingkat_kematangan" TEXT,
    "grade" "Grade" NOT NULL DEFAULT 'A',

    CONSTRAINT "Analisis_pkey" PRIMARY KEY ("id")
);
