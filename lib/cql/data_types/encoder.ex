defmodule CQL.DataTypes.Encoder do
  @moduledoc false

  require Bitwise
  require Logger

  def encode(nil),                            do: encode({nil, nil})
  def encode(%NaiveDateTime{} = value),       do: encode({:timestamp, value})
  def encode(%DateTime{} = value),            do: encode({:timestamp, value})
  def encode(%Time{} = value),                do: encode({:time, value})
  def encode(%Date{} = value),                do: encode({:date, value})
  def encode(value) when is_integer(value),   do: encode({:int, value})
  def encode(value) when is_float(value),     do: encode({:double, value})
  def encode(value) when is_binary(value),    do: encode({:text, value})
  def encode(value) when is_boolean(value),   do: encode({:boolean, value})
  def encode({_,_,_,_} = value),              do: encode({:inet, value})
  def encode({_,_,_,_,_,_} = value),          do: encode({:inet, value})

  def encode({type, value}), do: encode(value, type)

  def encode(value, type), do: type |> enc(value) |> bytes

  def byte(n) when is_integer(n), do: <<n::integer-8>>
  def byte(_), do: :error

  def boolean(false), do: byte(0)
  def boolean(true),  do: byte(1)
  def boolean(_),     do: :error

  def tinyint(n) when is_integer(n), do: <<n::signed-integer-8>>
  def tinyint(_), do: :error

  def signed_short(n) when is_integer(n), do: <<n::signed-integer-16>>
  def signed_short(_), do: :error

  def short(n) when is_integer(n), do: <<n::integer-16>>
  def short(_), do: :error

  def int(n) when is_integer(n), do: <<n::signed-integer-32>>
  def int(_), do: :error

  def long(n) when is_integer(n), do: <<n::signed-integer-64>>
  def long(_), do: :error

  def float(x) when is_float(x), do: <<x::float-32>>
  def float(_), do: :error

  def double(x) when is_float(x), do: <<x::float-64>>
  def double(_), do: :error

  def string(str) when is_binary(str), do: (str |> String.length |> short) <> <<str::bytes>>
  def string(_), do: :error

  def long_string(str) when is_binary(str), do: (str |> String.length |> int) <> <<str::bytes>>
  def long_string(_), do: :error

  def uuid(str) do
    try do
      UUID.string_to_binary!(str)
    rescue
      ArgumentError -> :error
    end
  end

  def string_list(list) when is_list(list) do
    if Enum.all?(list, &is_binary/1) do
      n = Enum.count(list)
      buffer = list |> Enum.map(&string/1) |> Enum.join
      short(n) <> <<buffer::bytes>>
    else
      :error
    end
  end

  def bytes(nil), do: int(-1)
  def bytes(bytes) when is_binary(bytes), do: int(byte_size(bytes)) <> <<bytes::bytes>>
  def bytes(_), do: :error

  def short_bytes(nil), do: int(-1)
  def short_bytes(bytes) when is_binary(bytes), do: short(byte_size(bytes)) <> <<bytes::bytes>>
  def short_bytes(_), do: :error

  def inet(ip) when is_tuple(ip), do: ip |> Tuple.to_list |> inet
  def inet(ip) when is_list(ip), do: ip |> Enum.map(&byte/1) |> Enum.join
  def inet(_), do: :error

  def string_map(map) when is_map(map) do
    if map |> Map.values |> Enum.all?(&is_binary/1) do
      n = Enum.count(map)
      buffer = map |> Enum.map(fn {k, v} -> string(k) <> string(v) end) |> Enum.join
      short(n) <> <<buffer::bytes>>
    else
      :error
    end
  end

  def string_map(_), do: :error

  def string_multimap(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, string_list(v)} end)
    |> string_map
  end

  def string_multimap(_), do: :error

  def bytes_map(map) do
    size = Enum.count(map)
    buffer =
      map
      |> Enum.map(fn {k, v} -> string(k) <> bytes(v) end)
      |> Enum.join

    short(size) <> <<buffer::bytes>>
  end

  def list(list, type) do
    size = Enum.count(list)
    buffer =
      list
      |> Enum.map(&encode(&1, type))
      |> Enum.join

    int(size) <> <<buffer::bytes>>
  end

  def map(map, {type}), do: map(map, {:text, type})
  def map(map, {ktype, vtype}) do
    size = Enum.count(map)
    buffer =
      map
      |> Enum.map(fn {k, v} -> encode(k, ktype) <> encode(v, vtype) end)
      |> Enum.join

    int(size) <> <<buffer::bytes>>
  end

  def set(set, type) do
    set |> MapSet.to_list |> list(type)
  end

  def tuple(tuple, types) do
    list = Tuple.to_list(tuple)
    size = Enum.count(list)
    buffer =
      list
      |> Enum.zip(types)
      |> Enum.map(fn {v, t} -> encode(v, t) end)
      |> Enum.join

    short(size) <> <<buffer::bytes>>
  end

  def varint(n) do
    bytes = int_bytes(n)
    bits = bytes * 8
    int(bytes) <> <<n::signed-integer-size(bits)>>
  end

  def decimal({unscaled, scale}) do
    int(scale) <> varint(unscaled)
  end

  def text(value) when is_atom(value), do: Atom.to_string(value)
  def text(value) when is_binary(value), do: value

  def blob(value), do: :erlang.term_to_binary(value)

  def date(date), do: CQL.DataTypes.Date.encode(date)
  def time(time), do: CQL.DataTypes.Time.encode(time)
  def timestamp(t), do: CQL.DataTypes.Timestamp.encode(t)

  def consistency(name) do
    name |> CQL.Consistency.code |> short
  end

  ### Helpers ###

  def prepend(list, item), do: [item | list]
  def prepend(list, _, false), do: list
  def prepend(list, item, true), do: [item | list]
  def prepend(list, _, nil), do: list
  def prepend(list, item, _), do: [item | list]
  def prepend_not_nil(list, nil, _func), do: list
  def prepend_not_nil(list, item, func), do: [apply(__MODULE__, func, [item]) | list]

  def ok(:error), do: :error
  def ok(value),  do: {:ok, value}

  def names_to_flag(names, flags) do
    names
    |> Enum.map(&Map.fetch!(flags, &1))
    |> Enum.reduce(0, &Bitwise.bor(&1, &2))
  end

  def zip(types, values) when is_map(values) do
    zip(types, Enum.to_list(values))
  end

  def zip(types, [{key, _} | _] = values) when is_list(values) and is_atom(key) do
    values =
      values
      |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
      |> Enum.into(%{})

    Enum.map(types, fn {name, type} -> {type, values[name]} end)
  end

  def zip(types, values) when is_list(values) do
    types
    |> Keyword.values
    |> Enum.zip(values)
  end

  def zip(_, values) when is_nil(values), do: nil

  def values(list) when is_list(list) do
    parts = Enum.map(list, &CQL.DataTypes.encode/1)

    if Enum.any?(parts, &(&1 == :error)) do
      Logger.error("Failed to encode values #{inspect list} with parts: #{inspect parts}")
      :error
    else
      n = Enum.count(list)
      Enum.join([short(n) | parts])
    end
  end

  def values(map) when is_map(map) do
    parts = Enum.flat_map map, fn {k, v} ->
      [string(to_string(k)), CQL.DataTypes.encode(v)]
    end

    if Enum.any?(parts, &(&1 == :error)) do
      Logger.error("Failed to encode values #{inspect map} with parts: #{inspect parts}")
      :error
    else
      n = Enum.count(map)
      Enum.join([short(n) | parts])
    end
  end

  def values(_), do: :error

  ### Utils ###

  defp int_bytes(x, acc \\ 0)
  defp int_bytes(x, acc) when x >  127 and x <   256, do: acc + 2
  defp int_bytes(x, acc) when x <= 127 and x >= -128, do: acc + 1
  defp int_bytes(x, acc) when x < -128 and x >= -256, do: acc + 2
  defp int_bytes(x, acc), do: int_bytes(Bitwise.bsr(x, 8), acc + 1)

  defp enc(:blob,      value), do: blob(value)

  defp enc(_type, nil), do: int(-1)
  defp enc(_type, :not_set), do: int(-2)

  defp enc(:ascii,     value), do: value
  defp enc(:bigint,    value), do: long(value)
  defp enc(:boolean,   true),  do: byte(1)
  defp enc(:boolean,   false), do: byte(0)
  defp enc(:counter,   value), do: long(value)
  defp enc(:date,      value), do: date(value)
  defp enc(:decimal,   value), do: decimal(value)
  defp enc(:double,    value), do: double(value)
  defp enc(:float,     value), do: float(value)
  defp enc(:inet,      value), do: inet(value)
  defp enc(:int,       value), do: int(value)
  defp enc(:smallint,  value), do: short(value)
  defp enc(:text,      value), do: text(value)
  defp enc(:time,      value), do: time(value)
  defp enc(:timestamp, value), do: timestamp(value)
  defp enc(:timeuuid,  value), do: uuid(value)
  defp enc(:tinyint,   value), do: tinyint(value)
  defp enc(:uuid,      value), do: uuid(value)
  defp enc(:varchar,   value), do: text(value)
  defp enc(:varint,    value), do: varint(value)

  defp enc({:list, type},   value), do: list(value, type)
  defp enc({:map, type},    value), do: map(value, type)
  defp enc({:set, type},    value), do: set(value, type)
  defp enc({:tuple, types}, value), do: tuple(value, types)
end
