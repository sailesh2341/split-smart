package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/lib/pq"
)

type ExpenseHandler struct {
	DB *sql.DB
}

type ExpenseFileResponse struct {
	URL  string `json:"url"`
	Type string `json:"type"`
}

type ExpenseSplitResponse struct {
	UserID      string  `json:"user_id"`
	Name        string  `json:"name"`
	Email       string  `json:"email"`
	ShareAmount float64 `json:"share_amount"`
	Paid        bool    `json:"paid"`
}

type ExpenseResponse struct {
	ID          string                 `json:"id"`
	GroupID     string                 `json:"group_id"`
	CreatedBy   string                 `json:"created_by"`
	Amount      float64                `json:"amount"`
	Description string                 `json:"description"`
	OrderType   string                 `json:"order_type"`
	Status      string                 `json:"status"`
	Files       []ExpenseFileResponse  `json:"files"`
	Splits      []ExpenseSplitResponse `json:"splits"`
}

type createExpenseRequest struct {
	Amount      float64               `json:"amount"`
	Description string                `json:"description"`
	OrderType   string                `json:"order_type"`
	Files       []ExpenseFileResponse `json:"files"`
	Splits      []createExpenseSplit  `json:"splits"`
}

type createExpenseSplit struct {
	UserID      string  `json:"user_id"`
	ShareAmount float64 `json:"share_amount"`
}

func (h *ExpenseHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	groupID := mux.Vars(r)["groupId"]
	orderTypeFilter := strings.TrimSpace(r.URL.Query().Get("order_types"))

	if !h.isGroupMember(groupID, userID) {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	query := `
		SELECT e.id, e.group_id, e.created_by, e.amount, e.description, ot.name, e.status
		FROM expenses e
		JOIN order_types ot ON ot.id = e.order_type_id
		WHERE e.group_id = $1 AND e.deleted_at IS NULL`
	args := []interface{}{groupID}

	if orderTypeFilter != "" {
		names := strings.Split(orderTypeFilter, ",")
		query += ` AND ot.name = ANY($2)`
		args = append(args, pq.Array(cleanStringList(names)))
	}

	query += ` ORDER BY e.created_at DESC`

	rows, err := h.DB.Query(query, args...)
	if err != nil {
		http.Error(w, "Failed to load expenses", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	expenses := []ExpenseResponse{}
	for rows.Next() {
		var expense ExpenseResponse
		if err := rows.Scan(
			&expense.ID,
			&expense.GroupID,
			&expense.CreatedBy,
			&expense.Amount,
			&expense.Description,
			&expense.OrderType,
			&expense.Status,
		); err != nil {
			http.Error(w, "Failed to parse expenses", http.StatusInternalServerError)
			return
		}
		expense.Files = h.filesForExpense(expense.ID)
		expense.Splits = h.splitsForExpense(expense.ID)
		expenses = append(expenses, expense)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(expenses)
}

func (h *ExpenseHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	groupID := mux.Vars(r)["groupId"]
	var req createExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
		req.Amount <= 0 ||
		req.Description == "" ||
		req.OrderType == "" {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	if !h.isGroupMember(groupID, userID) {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, "Failed to create expense", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	orderTypeID, err := upsertOrderType(tx, groupID, req.OrderType)
	if err != nil {
		http.Error(w, "Failed to save order type", http.StatusInternalServerError)
		return
	}

	expense := ExpenseResponse{
		ID:          uuid.New().String(),
		GroupID:     groupID,
		CreatedBy:   userID,
		Amount:      req.Amount,
		Description: req.Description,
		OrderType:   req.OrderType,
		Status:      "UNPAID",
		Files:       req.Files,
		Splits:      []ExpenseSplitResponse{},
	}

	if _, err := tx.Exec(
		`INSERT INTO expenses (id, group_id, created_by, amount, description, order_type_id, status)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		expense.ID,
		groupID,
		userID,
		req.Amount,
		req.Description,
		orderTypeID,
		expense.Status,
	); err != nil {
		http.Error(w, "Failed to save expense", http.StatusInternalServerError)
		return
	}

	for _, file := range req.Files {
		if file.URL == "" || file.Type == "" {
			continue
		}
		if _, err := tx.Exec(
			`INSERT INTO expense_files (id, expense_id, file_url, file_type) VALUES ($1, $2, $3, $4)`,
			uuid.New().String(),
			expense.ID,
			file.URL,
			file.Type,
		); err != nil {
			http.Error(w, "Failed to save expense file", http.StatusInternalServerError)
			return
		}
	}

	splits := normalizeSplits(req.Splits, userID, req.Amount)
	if !validSplitTotal(splits, req.Amount) {
		http.Error(w, "Split total must equal expense amount", http.StatusBadRequest)
		return
	}
	for _, split := range splits {
		if !h.isGroupMember(groupID, split.UserID) {
			http.Error(w, "Split user is not in group", http.StatusBadRequest)
			return
		}
		if _, err := tx.Exec(
			`INSERT INTO expense_splits (expense_id, user_id, share_amount, paid)
			 VALUES ($1, $2, $3, false)`,
			expense.ID,
			split.UserID,
			split.ShareAmount,
		); err != nil {
			http.Error(w, "Failed to save expense split", http.StatusInternalServerError)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "Failed to save expense", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	expense.Splits = h.splitsForExpense(expense.ID)
	json.NewEncoder(w).Encode(expense)
}

func (h *ExpenseHandler) OrderTypes(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	groupID := mux.Vars(r)["groupId"]

	if !h.isGroupMember(groupID, userID) {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	rows, err := h.DB.Query(
		`SELECT name FROM order_types WHERE group_id = $1 ORDER BY name`,
		groupID,
	)
	if err != nil {
		http.Error(w, "Failed to load order types", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	orderTypes := []string{}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			http.Error(w, "Failed to parse order types", http.StatusInternalServerError)
			return
		}
		orderTypes = append(orderTypes, name)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(orderTypes)
}

func (h *ExpenseHandler) isGroupMember(groupID string, userID string) bool {
	var exists bool
	err := h.DB.QueryRow(
		`SELECT EXISTS(
			SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2
		)`,
		groupID,
		userID,
	).Scan(&exists)
	return err == nil && exists
}

func (h *ExpenseHandler) MarkPaid(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	expenseID := mux.Vars(r)["expenseId"]

	result, err := h.DB.Exec(
		`UPDATE expenses SET status = 'PAID' WHERE id = $1 AND created_by = $2 AND deleted_at IS NULL`,
		expenseID,
		userID,
	)
	if err != nil {
		http.Error(w, "Failed to mark paid", http.StatusInternalServerError)
		return
	}
	affected, _ := result.RowsAffected()
	if affected == 0 {
		http.Error(w, "Only the expense owner can mark paid", http.StatusForbidden)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "PAID"})
}

func (h *ExpenseHandler) filesForExpense(expenseID string) []ExpenseFileResponse {
	rows, err := h.DB.Query(
		`SELECT file_url, file_type FROM expense_files WHERE expense_id = $1 ORDER BY id`,
		expenseID,
	)
	if err != nil {
		return []ExpenseFileResponse{}
	}
	defer rows.Close()

	files := []ExpenseFileResponse{}
	for rows.Next() {
		var file ExpenseFileResponse
		if err := rows.Scan(&file.URL, &file.Type); err == nil {
			files = append(files, file)
		}
	}
	return files
}

func (h *ExpenseHandler) splitsForExpense(expenseID string) []ExpenseSplitResponse {
	rows, err := h.DB.Query(
		`SELECT u.id, u.name, u.email, es.share_amount, es.paid
		 FROM expense_splits es
		 JOIN users u ON u.id = es.user_id
		 WHERE es.expense_id = $1
		 ORDER BY u.name`,
		expenseID,
	)
	if err != nil {
		return []ExpenseSplitResponse{}
	}
	defer rows.Close()

	splits := []ExpenseSplitResponse{}
	for rows.Next() {
		var split ExpenseSplitResponse
		if err := rows.Scan(
			&split.UserID,
			&split.Name,
			&split.Email,
			&split.ShareAmount,
			&split.Paid,
		); err == nil {
			splits = append(splits, split)
		}
	}
	return splits
}

func normalizeSplits(splits []createExpenseSplit, creatorID string, amount float64) []createExpenseSplit {
	if len(splits) == 0 {
		return []createExpenseSplit{{UserID: creatorID, ShareAmount: amount}}
	}
	return splits
}

func validSplitTotal(splits []createExpenseSplit, amount float64) bool {
	totalCents := 0
	for _, split := range splits {
		if split.ShareAmount <= 0 {
			return false
		}
		totalCents += int(split.ShareAmount*100 + 0.5)
	}
	amountCents := int(amount*100 + 0.5)
	return totalCents == amountCents
}

func upsertOrderType(tx *sql.Tx, groupID string, name string) (string, error) {
	var existingID string
	err := tx.QueryRow(
		`SELECT id FROM order_types WHERE group_id = $1 AND name = $2`,
		groupID,
		name,
	).Scan(&existingID)
	if err == nil {
		return existingID, nil
	}
	if err != sql.ErrNoRows {
		return "", err
	}

	newID := uuid.New().String()
	_, err = tx.Exec(
		`INSERT INTO order_types (id, group_id, name) VALUES ($1, $2, $3)`,
		newID,
		groupID,
		name,
	)
	return newID, err
}

func cleanStringList(values []string) []string {
	cleaned := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			cleaned = append(cleaned, value)
		}
	}
	return cleaned
}
