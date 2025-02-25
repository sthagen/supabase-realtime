defmodule Realtime.Tenants.Connect.CheckConnection do
  @moduledoc """
  Check tenant database connection.
  """
  alias Realtime.Database

  @behaviour Realtime.Tenants.Connect.Piper
  @impl true
  def run(acc) do
    %{tenant: tenant} = acc

    case Database.check_tenant_connection(tenant) do
      {:ok, conn} -> {:ok, %{acc | db_conn_pid: conn, db_conn_reference: Process.monitor(conn)}}
      {:error, error} -> {:error, error}
    end
  end
end
