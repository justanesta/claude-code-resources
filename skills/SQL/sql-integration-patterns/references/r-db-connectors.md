# R Database Connectors

Reference for connecting R to relational databases using DBI, dbplyr, RPostgres, odbc, and the pool package.

---

## DBI -- The Universal Interface

### Basic connection and queries

```r
library(DBI)
library(RPostgres)

con <- dbConnect(
  Postgres(),
  host = Sys.getenv("DB_HOST"), port = 5432, dbname = "analytics",
  user = Sys.getenv("DB_USER"), password = Sys.getenv("DB_PASSWORD")
)

# Parameterized query -- always use params, never paste()
orders <- dbGetQuery(con, "
  SELECT order_id, customer_id, total
  FROM orders WHERE region = $1 AND status = $2
", params = list("us-west", "shipped"))

# Insert data
dbExecute(con, "INSERT INTO audit_log (action, user_id) VALUES ($1, $2)",
          params = list("export", 42))

dbDisconnect(con)
```

### Writing data frames

```r
con <- dbConnect(Postgres(), dbname = "analytics")

monthly_summary <- data.frame(
  month = as.Date(c("2025-01-01", "2025-02-01")),
  revenue = c(150000, 175000),
  order_count = c(1200, 1450)
)

dbWriteTable(con, "monthly_summary", monthly_summary, overwrite = TRUE)
dbWriteTable(con, Id(schema = "reporting", table = "monthly_summary"),
             monthly_summary, overwrite = TRUE)
dbDisconnect(con)
```

### Transactions

```r
con <- dbConnect(Postgres(), dbname = "analytics")
dbBegin(con)
tryCatch({
  dbExecute(con, "UPDATE accounts SET balance = balance - $1 WHERE id = $2", params = list(100, 1))
  dbExecute(con, "UPDATE accounts SET balance = balance + $1 WHERE id = $2", params = list(100, 2))
  dbCommit(con)
}, error = function(e) {
  dbRollback(con)
  stop("Transfer failed: ", conditionMessage(e))
})
dbDisconnect(con)
```

---

## dbplyr -- dplyr Verbs Translated to SQL

Data stays in the database until you call `collect()`.

```r
library(dplyr)
library(dbplyr)

con <- dbConnect(Postgres(), dbname = "analytics")
orders_tbl <- tbl(con, "orders")
customers_tbl <- tbl(con, in_schema("public", "customers"))

# Build a query -- no data moves yet
revenue_by_segment <- orders_tbl |>
  filter(status == "shipped", ordered_at >= "2025-01-01") |>
  inner_join(customers_tbl, by = "customer_id") |>
  group_by(segment) |>
  summarise(
    order_count = n(),
    total_revenue = sum(total, na.rm = TRUE),
    avg_order_value = mean(total, na.rm = TRUE)
  ) |>
  arrange(desc(total_revenue))

show_query(revenue_by_segment)  # see generated SQL
result <- collect(revenue_by_segment)  # pull into R

# Use sql() for untranslatable functions
orders_tbl |>
  mutate(order_month = sql("date_trunc('month', ordered_at)")) |>
  group_by(order_month) |>
  summarise(revenue = sum(total, na.rm = TRUE)) |>
  collect()

# compute() creates a temp table in the database
active_custs <- customers_tbl |> filter(is_active == TRUE) |> compute()
dbDisconnect(con)
```

---

## odbc -- ODBC Connections (SQL Server, etc.)

```r
library(DBI)
library(odbc)

# SQL Server
con <- dbConnect(odbc(),
  Driver = "ODBC Driver 18 for SQL Server",
  Server = "sqlserver.internal", Database = "app_db",
  UID = Sys.getenv("SQL_USER"), PWD = Sys.getenv("SQL_PASSWORD"), Port = 1433
)

# Snowflake
con_sf <- dbConnect(odbc(),
  Driver = "Snowflake",
  Server = paste0(Sys.getenv("SF_ACCOUNT"), ".snowflakecomputing.com"),
  Database = "ANALYTICS", Schema = "MARTS",
  Warehouse = "ANALYSIS_WH", Role = "ANALYST",
  UID = Sys.getenv("SF_USER"), PWD = Sys.getenv("SF_PASSWORD")
)

# odbc uses ? for parameter placeholders
result <- dbGetQuery(con, "SELECT order_id, total FROM orders WHERE region = ? AND status = ?",
                     params = list("us-west", "shipped"))
dbDisconnect(con)
```

---

## pool Package -- Connection Pooling for Shiny

```r
library(pool)
library(RPostgres)

pool <- dbPool(
  Postgres(),
  host = Sys.getenv("DB_HOST"), dbname = "analytics",
  user = Sys.getenv("DB_USER"), password = Sys.getenv("DB_PASSWORD"),
  minSize = 2, maxSize = 10, idleTimeout = 60
)

# Use pool exactly like a DBI connection
orders <- dbGetQuery(pool, "SELECT * FROM orders WHERE status = $1", params = list("shipped"))
tbl(pool, "orders") |> filter(status == "shipped") |> collect()
```

### Shiny app with pool

```r
library(shiny)
library(pool)
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

pool <- dbPool(Postgres(), dbname = "analytics",
               host = Sys.getenv("DB_HOST"), user = Sys.getenv("DB_USER"),
               password = Sys.getenv("DB_PASSWORD"))
onStop(function() poolClose(pool))

ui <- fluidPage(
  selectInput("region", "Region:", choices = c("us-west", "us-east", "eu")),
  tableOutput("orders_table")
)

server <- function(input, output, session) {
  output$orders_table <- renderTable({
    tbl(pool, "orders") |>
      filter(region == !!input$region, status == "shipped") |>
      arrange(desc(ordered_at)) |>
      head(50) |>
      collect()
  })
}

shinyApp(ui, server)
```

---

## Error Handling

```r
safe_query <- function(con, sql, params = NULL) {
  tryCatch({
    dbGetQuery(con, sql, params = params)
  }, error = function(e) {
    message("Database error: ", conditionMessage(e))
    if (!dbIsValid(con)) message("Connection lost. Reconnecting...")
    return(NULL)
  })
}
```

---

## Edge Cases

- **dbplyr translation limits**: Not all R functions translate to SQL. Use `sql()` for `date_trunc()`, `string_agg()`, etc.
- **Column name conflicts**: dbplyr appends `.x`/`.y` on joins with same-named columns. Rename before joining.
- **Large result sets**: Use `dbFetch()` with `n` parameter for batched retrieval.
- **Schema qualification**: Use `in_schema("s", "t")` with `tbl()` or `Id(schema="s", table="t")` with DBI.
- **Timezone handling**: Set `Sys.setenv(TZ = "UTC")` at script start for consistent timestamp behavior.
- **Pool validation**: The pool package auto-validates connections; stale ones are replaced transparently.
