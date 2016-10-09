# Cassandra

[![Build Status](https://travis-ci.org/cafebazaar/elixir-cassandra.svg?branch=master)](https://travis-ci.org/cafebazaar/elixir-cassandra)

An Elixir driver for Apache Cassandra.

This driver works with Cassandra Query Language version 3 (CQL3) and Cassandra's native protocol.

## Installation

Add `cassandra` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:cassandra, "~> 0.1.0-beta"}]
end
```

## Quick Start

```elixir
alias Cassandra.Connection

{:ok, conn} = Connection.start_link(keyspace: "system_schema")

{:ok, rows} = Connection.query(conn, "SELECT keyspace_name, table_name FROM tables;")

Enum.each rows, fn row ->
  IO.inspect(row)
end
```

