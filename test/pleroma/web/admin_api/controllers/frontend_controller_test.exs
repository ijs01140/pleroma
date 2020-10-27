# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.FrontendControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Config
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Workers.FrontendInstallerWorker

  @dir "test/frontend_static_test"

  setup do
    clear_config([:instance, :static_dir], @dir)
    File.mkdir_p!(Pleroma.Frontend.dir())

    on_exit(fn ->
      File.rm_rf(@dir)
    end)

    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "GET /api/pleroma/admin/frontends" do
    test "it lists available frontends", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/admin/frontends")
        |> json_response_and_validate_schema(:ok)

      assert Enum.map(response, & &1["name"]) ==
               Enum.map(Config.get([:frontends, :available]), fn {_, map} -> map["name"] end)

      refute Enum.any?(response, fn frontend -> frontend["installed"] == true end)
    end
  end

  describe "POST /api/pleroma/admin/frontends" do
    test "it installs a frontend", %{conn: conn} do
      clear_config([:frontends, :available], %{
        "pleroma" => %{
          "ref" => "fantasy",
          "name" => "pleroma",
          "build_url" => "http://gensokyo.2hu/builds/${ref}"
        }
      })

      Tesla.Mock.mock(fn %{url: "http://gensokyo.2hu/builds/fantasy"} ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/tesla_mock/frontend_dist.zip")}
      end)

      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/pleroma/admin/frontends", %{name: "pleroma"})
      |> json_response_and_validate_schema(:ok)

      assert_enqueued(
        worker: FrontendInstallerWorker,
        args: %{"name" => "pleroma", "opts" => %{}}
      )

      ObanHelpers.perform(all_enqueued(worker: FrontendInstallerWorker))

      assert File.exists?(Path.join([@dir, "frontends", "pleroma", "fantasy", "test.txt"]))

      response =
        conn
        |> get("/api/pleroma/admin/frontends")
        |> json_response_and_validate_schema(:ok)

      assert response == [
               %{
                 "build_url" => "http://gensokyo.2hu/builds/${ref}",
                 "git" => nil,
                 "installed" => true,
                 "name" => "pleroma",
                 "ref" => "fantasy"
               }
             ]
    end
  end
end
