defmodule Cldr.Unit.Test.ConversionData do
  @moduledoc false

  @conversion_test_data "test/support/data/conversion_test_data.txt"
  @external_resource @conversion_test_data
  @offset 1

  def conversion_test_data do
    @conversion_test_data
    |> File.read!()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
  end

  def conversions do
    conversion_test_data()
    |> Enum.with_index()
    |> Enum.map(&parse_test/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_test({"", _}) do
    nil
  end

  def parse_test({<<"#", _rest::binary>>, _}) do
    nil
  end

  @fields [:category, :from, :to, :factor, :result]

  def parse_test({test, index}) do
    test
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> zip(@fields)
    |> Enum.map(&transform/1)
    |> Map.new()
    |> Map.put(:line, index + @offset)
  end

  def zip(data, fields) do
    fields
    |> Enum.zip(data)
  end

  def transform({:factor, factor}) do
    factor =
      factor
      |> String.replace(" * x", "")
      |> String.replace(",", "")
      |> String.trim()
      |> String.split("/")
      |> resolve_factor

    {:factor, factor}
  rescue
    ArgumentError ->
      {:factor, factor}
  end

  @float "^([-+]?[0-9]*)\.([0-9]+)([eE]([-+]?[0-9]+))?$"
  def transform({:result, result}) do
    result = String.replace(result, ",", "")

    result =
      case Regex.run(~r/#{@float}/, result) do
        [float, _integer, "0"] ->
          {String.to_float(float), 0, 15}

        [float, _integer, fraction] ->
          {String.to_float(float), String.length(fraction), 15}

        [float, integer, fraction, _, exp] ->
          {
            String.to_float(float),
            rounding_from(integer, fraction, exp),
            precision_from(integer, fraction, exp)
          }
      end

    {:result, result}
  end

  def transform(other) do
    other
  end

  def rounding_from(_integer, "0", <<"-", exp::binary>>) do
    String.to_integer(exp)
  end

  def rounding_from(_integer, "0", _exp) do
    0
  end

  def rounding_from(_integer, fraction, <<"-", exp::binary>>) do
    String.length(fraction) + String.to_integer(exp)
  end

  def rounding_from(_integer, fraction, exp) do
    if String.to_integer(exp) >= String.length(fraction) do
      0
    else
      String.length(fraction)
    end
  end

  def precision_from(integer, "0", _exp) do
    String.length(integer) + 1
  end

  def precision_from(integer, fraction, <<"-", _exp::binary>>) do
    String.length(fraction) + String.length(integer)
  end

  def precision_from(integer, fraction, exp) do
    if String.length(fraction) < String.to_integer(exp) do
      String.length(fraction) + String.length(integer)
    else
      String.length(fraction)
    end
  end

  def resolve_factor([factor]) do
    to_number(factor)
  end

  def resolve_factor(other) do
    other
  end

  def to_number(number_string) when is_binary(number_string) do
    number_string
    |> String.split(".")
    |> to_number
  end

  def to_number([integer]) do
    String.to_integer(integer)
  end

  def to_number([integer, fraction]) do
    String.to_float(integer <> "." <> fraction)
  end

  def round(%Cldr.Unit{value: value} = unit, digits, significant) do
    value =
      value
      |> round_precision(significant)
      |> round(digits)

    %{unit | value: value}
  end

  def round(number, rounding) when rounding > 15 do
    number
  end

  def round(float, digits) when is_float(float) do
    Float.round(float, digits)
  end

  def round(%Decimal{} = decimal, digits) do
    Decimal.round(decimal, digits)
  end

  def round(other, _digits) do
    other
  end

  def round_precision(value, _) when value == 0.0 do
    value
  end

  def round_precision(integer, round_digits) when is_integer(integer) do
    number_of_digits = Cldr.Digits.number_of_integer_digits(integer)
    p = Cldr.Math.power(10, number_of_digits) |> Decimal.new()
    d = Decimal.new(integer)

    d
    |> Decimal.div(p)
    |> Decimal.round(round_digits)
    |> Decimal.mult(p)
    |> Decimal.to_integer()
  end

  def round_precision(%Cldr.Unit{value: value} = unit, round_digits) do
    %{unit | value: round_precision(value, round_digits)}
  end

  def round_precision(float_or_decimal, digits) do
    Cldr.Math.round_significant(float_or_decimal, digits)
  end

  # Just for testing support. It does not touch
  # integer units.

  def to_float_unit(%Cldr.Unit{value: %Decimal{} = value} = unit) do
    value = Decimal.to_float(value)
    %{unit | value: value}
  end

  def to_float_unit(%Cldr.Unit{} = other) do
    other
  end
end
