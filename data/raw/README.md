# data/raw

Put the unzipped Olist CSVs here. Download the dataset from:
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Expected files (the CSVs themselves are gitignored, only this placeholder is tracked):

- olist_customers_dataset.csv
- olist_geolocation_dataset.csv
- olist_order_items_dataset.csv
- olist_order_payments_dataset.csv
- olist_order_reviews_dataset.csv
- olist_orders_dataset.csv
- olist_products_dataset.csv
- olist_sellers_dataset.csv
- product_category_name_translation.csv

Then run `../../load_db.sh` from the project root to build `data/olist.db`.
