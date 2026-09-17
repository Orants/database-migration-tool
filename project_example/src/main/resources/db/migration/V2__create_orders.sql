CREATE TABLE orders (
                        id          BIGSERIAL PRIMARY KEY,
                        user_id     BIGINT      NOT NULL REFERENCES users (id),
                        total_cents INTEGER     NOT NULL CHECK (total_cents >= 0),
                        placed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX orders_user_id_idx ON orders (user_id);