#!/usr/bin/env bash
# Builds data/olist.db from the raw Kaggle CSVs in data/raw/.
# Re-run any time to rebuild the database from scratch.
set -euo pipefail

cd "$(dirname "$0")"

DB_PATH="data/olist.db"
RAW_DIR="data/raw"

rm -f "$DB_PATH"

sqlite3 "$DB_PATH" < sql/00_schema.sql

import_csv() {
    local file="$1"
    local table="$2"
    sqlite3 "$DB_PATH" <<SQL
.mode csv
.import --skip 1 "$RAW_DIR/$file" $table
SQL
}

import_csv "olist_customers_dataset.csv"    customers
import_csv "olist_geolocation_dataset.csv"  geolocation
import_csv "olist_sellers_dataset.csv"      sellers
import_csv "product_category_name_translation.csv" product_category_name_translation
import_csv "olist_products_dataset.csv"     products
import_csv "olist_orders_dataset.csv"       orders
import_csv "olist_order_items_dataset.csv"  order_items
import_csv "olist_order_payments_dataset.csv" order_payments
import_csv "olist_order_reviews_dataset.csv" order_reviews

echo "Done. Row counts:"
sqlite3 "$DB_PATH" "
SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;
"
