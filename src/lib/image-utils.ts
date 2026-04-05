/**
 * Client-side image compression using Canvas API.
 * Resizes and compresses an image file before uploading.
 */

/**
 * Compresses an image file using the Canvas API.
 * @param file - The image File to compress
 * @param maxSize - Maximum width/height in pixels (default 800)
 * @param quality - JPEG/WebP quality 0-1 (default 0.85)
 * @returns A compressed File object in WebP format
 */
export async function compressImage(
  file: File,
  maxSize = 800,
  quality = 0.85,
): Promise<File> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const url = URL.createObjectURL(file)

    img.onload = () => {
      URL.revokeObjectURL(url)

      let { width, height } = img
      if (width > maxSize || height > maxSize) {
        if (width > height) {
          height = Math.round((height * maxSize) / width)
          width = maxSize
        } else {
          width = Math.round((width * maxSize) / height)
          height = maxSize
        }
      }

      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      if (!ctx) { reject(new Error('Canvas not supported')); return }

      ctx.drawImage(img, 0, 0, width, height)

      canvas.toBlob(
        (blob) => {
          if (!blob) { reject(new Error('Compression failed')); return }
          const compressed = new File([blob], file.name.replace(/\.\w+$/, '.webp'), {
            type: 'image/webp',
            lastModified: Date.now(),
          })
          resolve(compressed)
        },
        'image/webp',
        quality,
      )
    }

    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('Failed to load image'))
    }

    img.src = url
  })
}
