package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

type RequestHandler struct {
	DB *sql.DB
}

type CreateRequestPayload struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

type RequestResponse struct {
	ID                 string                 `json:"id"`
	ExpenseID          string                 `json:"expense_id"`
	ExpenseDescription string                 `json:"expense_description"`
	ExpenseAmount      float64                `json:"expense_amount"`
	RequestedBy        string                 `json:"requested_by"`
	RequestedByName    string                 `json:"requested_by_name"`
	Type               string                 `json:"type"`
	Status             string                 `json:"status"`
	Payload            map[string]interface{} `json:"payload"`
}

func (h *RequestHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	expenseID := mux.Vars(r)["expenseId"]
	var req CreateRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Type == "" {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	payloadBytes, err := json.Marshal(req.Payload)
	if err != nil {
		http.Error(w, "Invalid payload", http.StatusBadRequest)
		return
	}

	var ownerID string
	var groupID string
	if err := h.DB.QueryRow(
		`SELECT created_by, group_id FROM expenses WHERE id = $1 AND deleted_at IS NULL`,
		expenseID,
	).Scan(&ownerID, &groupID); err != nil {
		http.Error(w, "Expense not found", http.StatusNotFound)
		return
	}

	var isMember bool
	if err := h.DB.QueryRow(
		`SELECT EXISTS(
			SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2
		)`,
		groupID,
		userID,
	).Scan(&isMember); err != nil || !isMember {
		http.Error(w, "Expense not found", http.StatusNotFound)
		return
	}

	status := "PENDING"
	if ownerID == userID {
		status = "APPROVED"
	}

	response := RequestResponse{
		ID:          uuid.New().String(),
		ExpenseID:   expenseID,
		RequestedBy: userID,
		Type:        req.Type,
		Status:      status,
		Payload:     req.Payload,
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	if _, err := tx.Exec(
		`INSERT INTO expense_requests (id, expense_id, requested_by, request_type, payload, status)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		response.ID,
		expenseID,
		userID,
		req.Type,
		string(payloadBytes),
		status,
	); err != nil {
		http.Error(w, "Failed to save request", http.StatusInternalServerError)
		return
	}

	if status == "APPROVED" {
		if err := applyApprovedRequest(tx, expenseID, req.Type, req.Payload); err != nil {
			http.Error(w, "Failed to apply request", http.StatusInternalServerError)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to save request", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func (h *RequestHandler) ListForOwner(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	rows, err := h.DB.Query(
		`SELECT er.id, er.expense_id, e.description, e.amount, er.requested_by, u.name, er.request_type, er.payload, er.status
		 FROM expense_requests er
		 JOIN expenses e ON e.id = er.expense_id
		 JOIN users u ON u.id = er.requested_by
		 WHERE e.created_by = $1
		 ORDER BY er.created_at DESC`,
		userID,
	)
	if err != nil {
		http.Error(w, "Failed to load requests", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	requests := []RequestResponse{}
	for rows.Next() {
		var request RequestResponse
		var payloadBytes []byte
		if err := rows.Scan(
			&request.ID,
			&request.ExpenseID,
			&request.ExpenseDescription,
			&request.ExpenseAmount,
			&request.RequestedBy,
			&request.RequestedByName,
			&request.Type,
			&payloadBytes,
			&request.Status,
		); err != nil {
			http.Error(w, "Failed to parse requests", http.StatusInternalServerError)
			return
		}
		request.Payload = map[string]interface{}{}
		_ = json.Unmarshal(payloadBytes, &request.Payload)
		requests = append(requests, request)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(requests)
}

func (h *RequestHandler) Approve(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	requestID := mux.Vars(r)["requestId"]

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "Failed to approve request", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	var expenseID string
	var requestType string
	var payloadBytes []byte
	var status string
	if err := tx.QueryRow(
		`SELECT er.expense_id, er.request_type, er.payload, er.status
		 FROM expense_requests er
		 JOIN expenses e ON e.id = er.expense_id
		 WHERE er.id = $1 AND e.created_by = $2`,
		requestID,
		userID,
	).Scan(&expenseID, &requestType, &payloadBytes, &status); err != nil {
		http.Error(w, "Request not found or not owned", http.StatusForbidden)
		return
	}

	if status != "PENDING" {
		http.Error(w, "Request already handled", http.StatusBadRequest)
		return
	}

	payload := map[string]interface{}{}
	_ = json.Unmarshal(payloadBytes, &payload)

	if err := applyApprovedRequest(tx, expenseID, requestType, payload); err != nil {
		http.Error(w, "Failed to apply request", http.StatusInternalServerError)
		return
	}

	if _, err := tx.Exec(
		`UPDATE expense_requests SET status = 'APPROVED' WHERE id = $1`,
		requestID,
	); err != nil {
		http.Error(w, "Failed to update request", http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to approve request", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "APPROVED"})
}

func (h *RequestHandler) Reject(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	requestID := mux.Vars(r)["requestId"]

	var status string
	if err := h.DB.QueryRow(
		`SELECT er.status
		 FROM expense_requests er
		 JOIN expenses e ON e.id = er.expense_id
		 WHERE er.id = $1 AND e.created_by = $2`,
		requestID,
		userID,
	).Scan(&status); err != nil {
		http.Error(w, "Request not found or not owned", http.StatusForbidden)
		return
	}

	if status != "PENDING" {
		http.Error(w, "Request already handled", http.StatusBadRequest)
		return
	}

	if _, err := h.DB.Exec(
		`UPDATE expense_requests SET status = 'REJECTED' WHERE id = $1`,
		requestID,
	); err != nil {
		http.Error(w, "Failed to reject request", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "REJECTED"})
}

func applyApprovedRequest(
	tx *sql.Tx,
	expenseID string,
	requestType string,
	payload map[string]interface{},
) error {
	switch requestType {
	case "MARK_PAID":
		_, err := tx.Exec(`UPDATE expenses SET status = 'PAID' WHERE id = $1`, expenseID)
		return err
	case "DELETE":
		_, err := tx.Exec(`UPDATE expenses SET deleted_at = now() WHERE id = $1`, expenseID)
		return err
	case "MODIFY":
		return applyModifyRequest(tx, expenseID, payload)
	default:
		return nil
	}
}

func applyModifyRequest(tx *sql.Tx, expenseID string, payload map[string]interface{}) error {
	var groupID string
	if err := tx.QueryRow(
		`SELECT group_id FROM expenses WHERE id = $1`,
		expenseID,
	).Scan(&groupID); err != nil {
		return err
	}

	if description, ok := payload["description"].(string); ok && description != "" {
		if _, err := tx.Exec(
			`UPDATE expenses SET description = $1 WHERE id = $2`,
			description,
			expenseID,
		); err != nil {
			return err
		}
	}

	if amountValue, ok := numberFromPayload(payload["amount"]); ok && amountValue > 0 {
		if _, err := tx.Exec(
			`UPDATE expenses SET amount = $1 WHERE id = $2`,
			amountValue,
			expenseID,
		); err != nil {
			return err
		}
		if err := redistributeSplits(tx, expenseID, amountValue); err != nil {
			return err
		}
	}

	if orderType, ok := payload["order_type"].(string); ok && orderType != "" {
		orderTypeID, err := upsertOrderType(tx, groupID, orderType)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(
			`UPDATE expenses SET order_type_id = $1 WHERE id = $2`,
			orderTypeID,
			expenseID,
		); err != nil {
			return err
		}
	}

	return nil
}

func redistributeSplits(tx *sql.Tx, expenseID string, amount float64) error {
	rows, err := tx.Query(
		`SELECT user_id FROM expense_splits WHERE expense_id = $1 ORDER BY user_id`,
		expenseID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	userIDs := []string{}
	for rows.Next() {
		var userID string
		if err := rows.Scan(&userID); err != nil {
			return err
		}
		userIDs = append(userIDs, userID)
	}
	if len(userIDs) == 0 {
		return nil
	}

	totalCents := int(amount*100 + 0.5)
	baseCents := totalCents / len(userIDs)
	remainder := totalCents % len(userIDs)

	for index, userID := range userIDs {
		cents := baseCents
		if index < remainder {
			cents++
		}
		share := float64(cents) / 100
		if _, err := tx.Exec(
			`UPDATE expense_splits SET share_amount = $1 WHERE expense_id = $2 AND user_id = $3`,
			share,
			expenseID,
			userID,
		); err != nil {
			return err
		}
	}
	return nil
}

func numberFromPayload(value interface{}) (float64, bool) {
	switch typed := value.(type) {
	case float64:
		return typed, true
	case int:
		return float64(typed), true
	case json.Number:
		parsed, err := typed.Float64()
		return parsed, err == nil
	default:
		return 0, false
	}
}
