# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.UpdateCredentialsTest do
  alias Pleroma.Repo
  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.User

  use Pleroma.Web.ConnCase

  import Mock
  import Mox
  import Pleroma.Factory

  setup do
    ConfigMock
    |> stub_with(Pleroma.Test.StaticConfig)

    :ok
  end

  describe "updating credentials" do
    setup do: oauth_access(["write:accounts"])
    setup :request_content_type

    test "sets user settings in a generic way", %{conn: conn} do
      res_conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            pleroma_fe: %{
              theme: "bla"
            }
          }
        })

      assert user_data = json_response_and_validate_schema(res_conn, 200)
      assert user_data["pleroma"]["settings_store"] == %{"pleroma_fe" => %{"theme" => "bla"}}

      user = Repo.get(User, user_data["id"])

      res_conn =
        conn
        |> assign(:user, user)
        |> patch("/api/v1/accounts/update_credentials", %{
          "pleroma_settings_store" => %{
            soapbox_fe: %{
              themeMode: "bla"
            }
          }
        })

      assert user_data = json_response_and_validate_schema(res_conn, 200)

      assert user_data["pleroma"]["settings_store"] ==
               %{
                 "pleroma_fe" => %{"theme" => "bla"},
                 "soapbox_fe" => %{"themeMode" => "bla"}
               }

      user = Repo.get(User, user_data["id"])

      clear_config([:instance, :federating], true)

      with_mock Pleroma.Web.Federator,
        publish: fn _activity -> :ok end do
        res_conn =
          conn
          |> assign(:user, user)
          |> patch("/api/v1/accounts/update_credentials", %{
            "pleroma_settings_store" => %{
              soapbox_fe: %{
                themeMode: "blub"
              }
            }
          })

        assert user_data = json_response_and_validate_schema(res_conn, 200)

        assert user_data["pleroma"]["settings_store"] ==
                 %{
                   "pleroma_fe" => %{"theme" => "bla"},
                   "soapbox_fe" => %{"themeMode" => "blub"}
                 }

        assert_called(Pleroma.Web.Federator.publish(:_))
      end
    end

    test "updates the user's bio", %{conn: conn} do
      user2 = insert(:user)

      raw_bio = "I drink #cofe with @#{user2.nickname}\n\nsuya.."

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{"note" => raw_bio})

      assert user_data = json_response_and_validate_schema(conn, 200)

      assert user_data["note"] ==
               ~s(I drink <a class="hashtag" data-tag="cofe" href="http://localhost:4001/tag/cofe">#cofe</a> with <span class="h-card"><a class="u-url mention" data-user="#{user2.id}" href="#{user2.ap_id}" rel="ugc">@<span>#{user2.nickname}</span></a></span><br/><br/>suya..)

      assert user_data["source"]["note"] == raw_bio

      user = Repo.get(User, user_data["id"])

      assert user.raw_bio == raw_bio
    end

    test "updating bio honours bio limit", %{conn: conn} do
      bio_limit = Config.get([:instance, :user_bio_length], 5000)

      raw_bio = String.duplicate(".", bio_limit + 1)

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{"note" => raw_bio})

      assert %{"error" => "Bio is too long"} = json_response_and_validate_schema(conn, 413)
    end

    test "updating name honours name limit", %{conn: conn} do
      name_limit = Config.get([:instance, :user_name_length], 100)

      name = String.duplicate(".", name_limit + 1)

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{"display_name" => name})

      assert %{"error" => "Name is too long"} = json_response_and_validate_schema(conn, 413)
    end

    test "when both name and bio exceeds the limit, display name error", %{conn: conn} do
      name_limit = Config.get([:instance, :user_name_length], 100)
      bio_limit = Config.get([:instance, :user_bio_length], 5000)

      name = String.duplicate(".", name_limit + 1)
      raw_bio = String.duplicate(".", bio_limit + 1)

      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "display_name" => name,
          "note" => raw_bio
        })

      assert %{"error" => "Name is too long"} = json_response_and_validate_schema(conn, 413)
    end

    test "updates the user's locking status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{locked: "true"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["locked"] == true
    end

    test "updates the user's chat acceptance status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{accepts_chat_messages: "false"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["accepts_chat_messages"] == false
    end

    test "updates the user's allow_following_move", %{user: user, conn: conn} do
      assert user.allow_following_move == true

      conn = patch(conn, "/api/v1/accounts/update_credentials", %{allow_following_move: "false"})

      assert refresh_record(user).allow_following_move == false
      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["allow_following_move"] == false
    end

    test "updates the user's default scope", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{default_scope: "unlisted"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["source"]["privacy"] == "unlisted"
    end

    test "updates the user's privacy", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{source: %{privacy: "unlisted"}})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["source"]["privacy"] == "unlisted"
    end

    test "updates the user's hide_followers status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_followers: "true"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["hide_followers"] == true
    end

    test "updates the user's discoverable status", %{conn: conn} do
      assert %{"source" => %{"pleroma" => %{"discoverable" => true}}} =
               conn
               |> patch("/api/v1/accounts/update_credentials", %{discoverable: "true"})
               |> json_response_and_validate_schema(:ok)

      assert %{"source" => %{"pleroma" => %{"discoverable" => false}}} =
               conn
               |> patch("/api/v1/accounts/update_credentials", %{discoverable: "false"})
               |> json_response_and_validate_schema(:ok)
    end

    test "updates the user's hide_followers_count and hide_follows_count", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          hide_followers_count: "true",
          hide_follows_count: "true"
        })

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["hide_followers_count"] == true
      assert user_data["pleroma"]["hide_follows_count"] == true
    end

    test "updates the user's skip_thread_containment option", %{user: user, conn: conn} do
      response =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{skip_thread_containment: "true"})
        |> json_response_and_validate_schema(200)

      assert response["pleroma"]["skip_thread_containment"] == true
      assert refresh_record(user).skip_thread_containment
    end

    test "updates the user's hide_follows status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_follows: "true"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["hide_follows"] == true
    end

    test "updates the user's hide_favorites status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{hide_favorites: "true"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["hide_favorites"] == true
    end

    test "updates the user's show_role status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{show_role: "false"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["source"]["pleroma"]["show_role"] == false
    end

    test "updates the user's no_rich_text status", %{conn: conn} do
      conn = patch(conn, "/api/v1/accounts/update_credentials", %{no_rich_text: "true"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["source"]["pleroma"]["no_rich_text"] == true
    end

    test "updates the user's name", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{"display_name" => "markorepairs"})

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["display_name"] == "markorepairs"

      update_activity = Repo.one(Pleroma.Activity)
      assert update_activity.data["type"] == "Update"
      assert update_activity.data["object"]["name"] == "markorepairs"
    end

    test "updates the user's AKAs", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "also_known_as" => ["https://mushroom.kingdom/users/mario"]
        })

      assert user_data = json_response_and_validate_schema(conn, 200)
      assert user_data["pleroma"]["also_known_as"] == ["https://mushroom.kingdom/users/mario"]
    end

    test "doesn't update non-url akas", %{conn: conn} do
      conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "also_known_as" => ["aReallyCoolGuy"]
        })

      assert json_response_and_validate_schema(conn, 403)
    end

    test "updates the user's avatar", %{user: user, conn: conn} do
      new_avatar = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      assert user.avatar == %{}

      res = patch(conn, "/api/v1/accounts/update_credentials", %{"avatar" => new_avatar})

      assert user_response = json_response_and_validate_schema(res, 200)
      assert user_response["avatar"] != User.avatar_url(user)

      user = User.get_by_id(user.id)
      refute user.avatar == %{}

      # Also resets it
      _res = patch(conn, "/api/v1/accounts/update_credentials", %{"avatar" => ""})

      user = User.get_by_id(user.id)
      assert user.avatar == nil
    end

    test "updates the user's avatar, upload_limit, returns a HTTP 413", %{conn: conn, user: user} do
      upload_limit = Config.get([:instance, :upload_limit]) * 8 + 8

      assert :ok ==
               File.write(Path.absname("test/tmp/large_binary.data"), <<0::size(upload_limit)>>)

      new_avatar_oversized = %Plug.Upload{
        content_type: nil,
        path: Path.absname("test/tmp/large_binary.data"),
        filename: "large_binary.data"
      }

      assert user.avatar == %{}

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{"avatar" => new_avatar_oversized})

      assert user_response = json_response_and_validate_schema(res, 413)
      assert user_response["avatar"] != User.avatar_url(user)

      user = User.get_by_id(user.id)
      assert user.avatar == %{}

      clear_config([:instance, :upload_limit], upload_limit)

      assert :ok == File.rm(Path.absname("test/tmp/large_binary.data"))
    end

    test "updates the user's banner", %{user: user, conn: conn} do
      new_header = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      res = patch(conn, "/api/v1/accounts/update_credentials", %{"header" => new_header})

      assert user_response = json_response_and_validate_schema(res, 200)
      assert user_response["header"] != User.banner_url(user)

      # Also resets it
      _res = patch(conn, "/api/v1/accounts/update_credentials", %{"header" => ""})

      user = User.get_by_id(user.id)
      assert user.banner == nil
    end

    test "updates the user's banner, upload_limit, returns a HTTP 413", %{conn: conn, user: user} do
      upload_limit = Config.get([:instance, :upload_limit]) * 8 + 8

      assert :ok ==
               File.write(Path.absname("test/tmp/large_binary.data"), <<0::size(upload_limit)>>)

      new_header_oversized = %Plug.Upload{
        content_type: nil,
        path: Path.absname("test/tmp/large_binary.data"),
        filename: "large_binary.data"
      }

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{"header" => new_header_oversized})

      assert user_response = json_response_and_validate_schema(res, 413)
      assert user_response["header"] != User.banner_url(user)

      user = User.get_by_id(user.id)
      assert user.banner == %{}

      clear_config([:instance, :upload_limit], upload_limit)

      assert :ok == File.rm(Path.absname("test/tmp/large_binary.data"))
    end

    test "updates the user's background", %{conn: conn, user: user} do
      new_header = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "pleroma_background_image" => new_header
        })

      assert user_response = json_response_and_validate_schema(res, 200)
      assert user_response["pleroma"]["background_image"]
      #
      # Also resets it
      _res =
        patch(conn, "/api/v1/accounts/update_credentials", %{"pleroma_background_image" => ""})

      user = User.get_by_id(user.id)
      assert user.background == nil
    end

    test "updates the user's background, upload_limit, returns a HTTP 413", %{
      conn: conn,
      user: user
    } do
      upload_limit = Config.get([:instance, :upload_limit]) * 8 + 8

      assert :ok ==
               File.write(Path.absname("test/tmp/large_binary.data"), <<0::size(upload_limit)>>)

      new_background_oversized = %Plug.Upload{
        content_type: nil,
        path: Path.absname("test/tmp/large_binary.data"),
        filename: "large_binary.data"
      }

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "pleroma_background_image" => new_background_oversized
        })

      assert %{"error" => "File is too large"} == json_response_and_validate_schema(res, 413)

      user = Repo.get(User, user.id)
      assert user.background == %{}

      clear_config([:instance, :upload_limit], upload_limit)

      assert :ok == File.rm(Path.absname("test/tmp/large_binary.data"))
    end

    test "adds avatar description with a new avatar", %{user: user, conn: conn} do
      new_avatar = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "avatar" => new_avatar,
          "avatar_description" => "me and pleroma tan"
        })

      assert json_response_and_validate_schema(res, 200)

      user = User.get_by_id(user.id)
      assert user.avatar["name"] == "me and pleroma tan"
    end

    test "adds avatar description to existing avatar", %{user: user, conn: conn} do
      new_avatar = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      assert user.avatar == %{}

      conn
      |> patch("/api/v1/accounts/update_credentials", %{"avatar" => new_avatar})

      assert conn
             |> assign(:user, User.get_by_id(user.id))
             |> patch("/api/v1/accounts/update_credentials", %{
               "avatar_description" => "me and pleroma tan"
             })
             |> json_response_and_validate_schema(200)

      user = User.get_by_id(user.id)
      assert user.avatar["name"] == "me and pleroma tan"
    end

    test "limit", %{user: user, conn: conn} do
      new_header = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      assert user.banner == %{}

      conn
      |> patch("/api/v1/accounts/update_credentials", %{"header" => new_header})

      description_limit = Config.get([:instance, :description_limit], 100)

      description = String.duplicate(".", description_limit + 1)

      conn =
        conn
        |> assign(:user, User.get_by_id(user.id))
        |> patch("/api/v1/accounts/update_credentials", %{
          "header_description" => description
        })

      assert %{"error" => "Banner description is too long"} =
               json_response_and_validate_schema(conn, 413)
    end

    test "Strip / from upload files", %{user: user, conn: conn} do
      new_image = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "../../../../nested/an_image.jpg"
      }

      assert user.avatar == %{}

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "avatar" => new_image,
          "header" => new_image,
          "pleroma_background_image" => new_image
        })

      assert user_response = json_response_and_validate_schema(res, 200)
      assert user_response["avatar"]
      assert user_response["header"]
      assert user_response["pleroma"]["background_image"]
      refute Regex.match?(~r"/nested/", user_response["avatar"])
      refute Regex.match?(~r"/nested/", user_response["header"])
      refute Regex.match?(~r"/nested/", user_response["pleroma"]["background_image"])

      user = User.get_by_id(user.id)
      refute user.avatar == %{}
    end

    test "requires 'write:accounts' permission" do
      token1 = insert(:oauth_token, scopes: ["read"])
      token2 = insert(:oauth_token, scopes: ["write", "follow"])

      for token <- [token1, token2] do
        conn =
          build_conn()
          |> put_req_header("content-type", "multipart/form-data")
          |> put_req_header("authorization", "Bearer #{token.token}")
          |> patch("/api/v1/accounts/update_credentials", %{})

        if token == token1 do
          assert %{"error" => "Insufficient permissions: write:accounts."} ==
                   json_response_and_validate_schema(conn, 403)
        else
          assert json_response_and_validate_schema(conn, 200)
        end
      end
    end

    test "updates profile emojos", %{user: user, conn: conn} do
      note = "*sips :blank:*"
      name = "I am :firefox:"

      ret_conn =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "note" => note,
          "display_name" => name
        })

      assert json_response_and_validate_schema(ret_conn, 200)

      conn = get(conn, "/api/v1/accounts/#{user.id}")

      assert user_data = json_response_and_validate_schema(conn, 200)

      assert user_data["note"] == note
      assert user_data["display_name"] == name
      assert [%{"shortcode" => "blank"}, %{"shortcode" => "firefox"}] = user_data["emojis"]
    end

    test "update fields", %{conn: conn} do
      fields = [
        %{"name" => "<a href=\"http://google.com\">foo</a>", "value" => "<script>bar</script>"},
        %{"name" => "link.io", "value" => "cofe.io"}
      ]

      account_data =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
        |> json_response_and_validate_schema(200)

      assert account_data["fields"] == [
               %{
                 "name" => "<a href=\"http://google.com\">foo</a>",
                 "value" => "bar",
                 "verified_at" => nil
               },
               %{
                 "name" => "link.io",
                 "value" => ~S(<a href="http://cofe.io" rel="ugc">cofe.io</a>),
                 "verified_at" => nil
               }
             ]

      assert account_data["source"]["fields"] == [
               %{
                 "name" => "<a href=\"http://google.com\">foo</a>",
                 "value" => "<script>bar</script>"
               },
               %{"name" => "link.io", "value" => "cofe.io"}
             ]
    end

    test "updates birth date", %{conn: conn} do
      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "birthday" => "2001-02-12"
        })

      assert user_data = json_response_and_validate_schema(res, 200)
      assert user_data["pleroma"]["birthday"] == "2001-02-12"
    end

    test "updates the user's show_birthday status", %{conn: conn} do
      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "show_birthday" => true
        })

      assert user_data = json_response_and_validate_schema(res, 200)
      assert user_data["source"]["pleroma"]["show_birthday"] == true
    end

    test "unsets birth date", %{conn: conn} do
      patch(conn, "/api/v1/accounts/update_credentials", %{
        "birthday" => "2001-02-12"
      })

      res =
        patch(conn, "/api/v1/accounts/update_credentials", %{
          "birthday" => ""
        })

      assert user_data = json_response_and_validate_schema(res, 200)
      assert user_data["pleroma"]["birthday"] == nil
    end

    test "emojis in fields labels", %{conn: conn} do
      fields = [
        %{"name" => ":firefox:", "value" => "is best 2hu"},
        %{"name" => "they wins", "value" => ":blank:"}
      ]

      account_data =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
        |> json_response_and_validate_schema(200)

      assert account_data["fields"] == [
               %{"name" => ":firefox:", "value" => "is best 2hu", "verified_at" => nil},
               %{"name" => "they wins", "value" => ":blank:", "verified_at" => nil}
             ]

      assert account_data["source"]["fields"] == [
               %{"name" => ":firefox:", "value" => "is best 2hu"},
               %{"name" => "they wins", "value" => ":blank:"}
             ]

      assert [%{"shortcode" => "blank"}, %{"shortcode" => "firefox"}] = account_data["emojis"]
    end

    test "update fields via x-www-form-urlencoded", %{conn: conn} do
      fields =
        [
          "fields_attributes[1][name]=link",
          "fields_attributes[1][value]=http://cofe.io",
          "fields_attributes[0][name]=foo",
          "fields_attributes[0][value]=bar"
        ]
        |> Enum.join("&")

      account =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> patch("/api/v1/accounts/update_credentials", fields)
        |> json_response_and_validate_schema(200)

      assert account["fields"] == [
               %{"name" => "foo", "value" => "bar", "verified_at" => nil},
               %{
                 "name" => "link",
                 "value" => ~S(<a href="http://cofe.io" rel="ugc">http://cofe.io</a>),
                 "verified_at" => nil
               }
             ]

      assert account["source"]["fields"] == [
               %{"name" => "foo", "value" => "bar"},
               %{"name" => "link", "value" => "http://cofe.io"}
             ]
    end

    test "update fields with empty name", %{conn: conn} do
      fields = [
        %{"name" => "foo", "value" => ""},
        %{"name" => "", "value" => "bar"}
      ]

      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
        |> json_response_and_validate_schema(200)

      assert account["fields"] == [
               %{"name" => "foo", "value" => "", "verified_at" => nil}
             ]
    end

    test "update fields when invalid request", %{conn: conn} do
      name_limit = Pleroma.Config.get([:instance, :account_field_name_length])
      value_limit = Pleroma.Config.get([:instance, :account_field_value_length])

      long_name = Enum.map(0..name_limit, fn _ -> "x" end) |> Enum.join()
      long_value = Enum.map(0..value_limit, fn _ -> "x" end) |> Enum.join()

      fields = [%{"name" => "foo", "value" => long_value}]

      assert %{"error" => "One or more field entries are too long"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response_and_validate_schema(413)

      fields = [%{"name" => long_name, "value" => "bar"}]

      assert %{"error" => "One or more field entries are too long"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response_and_validate_schema(413)

      clear_config([:instance, :max_account_fields], 1)

      fields = [
        %{"name" => "foo", "value" => "bar"},
        %{"name" => "link", "value" => "cofe.io"}
      ]

      assert %{"error" => "Too many field entries"} ==
               conn
               |> patch("/api/v1/accounts/update_credentials", %{"fields_attributes" => fields})
               |> json_response_and_validate_schema(413)
    end
  end

  describe "Mark account as bot" do
    setup do: oauth_access(["write:accounts"])
    setup :request_content_type

    test "changing actor_type to Service makes account a bot", %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{actor_type: "Service"})
        |> json_response_and_validate_schema(200)

      assert account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Service"
    end

    test "changing actor_type to Person makes account a human", %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{actor_type: "Person"})
        |> json_response_and_validate_schema(200)

      refute account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Person"
    end

    test "changing actor_type to Application causes error", %{conn: conn} do
      response =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{actor_type: "Application"})
        |> json_response_and_validate_schema(403)

      assert %{"error" => "Invalid request"} == response
    end

    test "changing bot field to true changes actor_type to Service", %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{bot: "true"})
        |> json_response_and_validate_schema(200)

      assert account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Service"
    end

    test "changing bot field to false changes actor_type to Person", %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{bot: "false"})
        |> json_response_and_validate_schema(200)

      refute account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Person"
    end

    test "actor_type field has a higher priority than bot", %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{
          actor_type: "Person",
          bot: "true"
        })
        |> json_response_and_validate_schema(200)

      refute account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Person"
    end
  end

  describe "Mark account as group" do
    setup do: oauth_access(["write:accounts"])
    setup :request_content_type

    test "changing actor_type to Group makes account a Group and enables bot indicator for backward compatibility",
         %{conn: conn} do
      account =
        conn
        |> patch("/api/v1/accounts/update_credentials", %{actor_type: "Group"})
        |> json_response_and_validate_schema(200)

      assert account["bot"]
      assert account["source"]["pleroma"]["actor_type"] == "Group"
    end
  end
end
