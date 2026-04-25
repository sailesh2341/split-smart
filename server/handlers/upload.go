package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

type UploadHandler struct {
	Dir string
}

func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
	if err := os.MkdirAll(h.Dir, 0755); err != nil {
		http.Error(w, "Failed to prepare upload directory", http.StatusInternalServerError)
		return
	}

	if err := r.ParseMultipartForm(20 << 20); err != nil {
		http.Error(w, "File too large or invalid upload", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Missing file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	extension := strings.ToLower(filepath.Ext(header.Filename))
	fileType := fileTypeFromExtension(extension)
	if fileType == "" {
		http.Error(w, "Only image and PDF files are supported", http.StatusBadRequest)
		return
	}

	filename := uuid.New().String() + extension
	destinationPath := filepath.Join(h.Dir, filename)
	destination, err := os.Create(destinationPath)
	if err != nil {
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}
	defer destination.Close()

	if _, err := io.Copy(destination, file); err != nil {
		http.Error(w, "Failed to save file", http.StatusInternalServerError)
		return
	}

	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	url := scheme + "://" + r.Host + "/uploads/" + filename

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"url":  url,
		"type": fileType,
	})
}

func fileTypeFromExtension(extension string) string {
	switch extension {
	case ".jpg", ".jpeg", ".png", ".webp":
		return "image"
	case ".pdf":
		return "pdf"
	default:
		return ""
	}
}
