defmodule Hipdster.XRPC do
  @moduledoc """
  Just some macros to make the XRPC interface easier to write
  """

  defmacro query(conn, method, params, [do: block]) do
    quote do
      def xrpc_query(unquote(conn), unquote(method), unquote(params), user) do
        unquote(block)
      end
    end
  end

  defmacro procedure(conn, method, params, [do: block]) do
    quote do
      def xrpc_procedure(unquote(conn), unquote(method), unquote(params), user) do
        unquote(block)
      end
    end
  end

end
