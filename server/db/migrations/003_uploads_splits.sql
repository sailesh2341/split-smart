CREATE TABLE IF NOT EXISTS expense_splits (
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_amount NUMERIC NOT NULL,
    paid BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (expense_id, user_id)
);
