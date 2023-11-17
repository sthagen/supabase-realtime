defmodule Realtime.ChannelsTest do
  use Realtime.DataCase, async: false

  alias Realtime.Channels
  alias Realtime.Api.Channel
  alias Realtime.Tenants

  @cdc "postgres_cdc_rls"

  setup do
    tenant = tenant_fixture()
    settings = Realtime.PostgresCdc.filter_settings(@cdc, tenant.extensions)
    settings = Map.put(settings, "id", tenant.external_id)
    settings = Map.put(settings, "db_socket_opts", [:inet])

    start_supervised!({Tenants.Migrations, settings})
    {:ok, conn} = Tenants.Connect.lookup_or_start_connection(tenant.external_id)
    truncate_table(conn, "realtime.channels")

    %{conn: conn, tenant: tenant}
  end

  describe "list/1" do
    test "list channels in tenant database", %{conn: conn, tenant: tenant} do
      channels = Stream.repeatedly(fn -> channel_fixture(tenant) end) |> Enum.take(10)
      assert {:ok, ^channels} = Channels.list_channels(conn)
    end
  end

  describe "get_channel_by_id/2" do
    test "fetches correct channel", %{tenant: tenant, conn: conn} do
      [channel | _] = Stream.repeatedly(fn -> channel_fixture(tenant) end) |> Enum.take(10)
      {:ok, res} = Channels.get_channel_by_id(channel.id, conn)
      assert channel == res
    end

    test "nil if channel does not exist", %{conn: conn} do
      assert {:ok, nil} = Channels.get_channel_by_id(0, conn)
    end
  end

  describe "create/2" do
    test "creates channel in tenant database", %{conn: conn} do
      name = random_string()
      assert {:ok, %Channel{name: ^name}} = Channels.create_channel(%{name: name}, conn)
    end
  end

  describe "get_channel_by_name/2" do
    test "fetches correct channel", %{conn: conn} do
      name = random_string()
      {:ok, channel} = Channels.create_channel(%{name: name}, conn)
      assert {:ok, ^channel} = Channels.get_channel_by_name(name, conn)
    end

    test "nil if channel does not exist", %{conn: conn} do
      assert {:ok, nil} == Channels.get_channel_by_name(random_string(), conn)
    end
  end
end
