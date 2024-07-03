defmodule Hexpds.Helpers do
  @moduledoc """
  Common macros & functions that make Elixir easier
  """

  # Gonna move some common stuff here soon

  defmacro def!({name, _, args}) do
    quote do
      def unquote({:"#{name}!", [], args}) do
        case unquote({name, [], args}) do
          {:ok, value} -> value
          {:error, error} -> raise error
        end
      end
    end
  end

  defmacro handle_errors(do: block) do
    quote do
      try do
        {:ok, unquote(block)}
      rescue
        error -> {:error, error}
      end
    end
  end
end
