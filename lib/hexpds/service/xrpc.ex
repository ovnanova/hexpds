defmodule Hexpds.XRPC do
  @moduledoc """
  Just some macros to make the XRPC interface easier to write
  """

  def blank do
    {:blob, %{mime_type: "application/octet-stream", data: ""}}
  end

  defmacro query(conn, method, params, ctx, do: block) do
    quote do
      def xrpc_query(unquote(conn), unquote(method), unquote(params), unquote(ctx)) do
        unquote(block)
      end
    end
  end

  defmacro procedure(conn, method, params, ctx, do: block) do
    quote do
      def xrpc_procedure(unquote(conn), unquote(method), unquote(params), unquote(ctx)) do
        unquote(block)
      end
    end
  end

  defmacro if_authed(ctx, token_type \\ :access, do: block) do
    quote do
      case unquote(ctx) do
        %{user: %Hexpds.User{}, token_type: unquote(token_type)} ->
          unquote(block)
        _ ->
          {401, %{error: "Unauthorized", message: "Not authorized"}}
      end
    end
  end

end
