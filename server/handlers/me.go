package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
)

type MeHandler struct {
	DB *sql.DB
}

type MeResponse struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

func (h *MeHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var res MeResponse
	err := h.DB.QueryRow(
		`SELECT id, name, email FROM users WHERE id = $1`,
		userID,
	).Scan(&res.ID, &res.Name, &res.Email)

	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(res)
}
