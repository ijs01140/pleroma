# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AccountController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [
      add_link_headers: 2,
      assign_account_by_id: 2,
      embed_relationships?: 1,
      json_response: 3
    ]

  alias Pleroma.Maps
  alias Pleroma.User
  alias Pleroma.UserNote
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.ListView
  alias Pleroma.Web.MastodonAPI.MastodonAPI
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.OAuth.OAuthController
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter
  alias Pleroma.Web.TwitterAPI.TwitterAPI
  alias Pleroma.Web.Utils.Params

  plug(Pleroma.Web.ApiSpec.CastAndValidate, replace_params: false)

  plug(:skip_auth when action in [:create, :lookup])

  plug(:skip_public_check when action in [:show, :statuses])

  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:accounts"]}
    when action in [:show, :followers, :following]
  )

  plug(
    OAuthScopesPlug,
    %{fallback: :proceed_unauthenticated, scopes: ["read:statuses"]}
    when action == :statuses
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:accounts"]}
    when action in [:verify_credentials, :endorsements]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:accounts"]}
    when action in [:update_credentials, :note, :endorse, :unendorse]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action == :lists)

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "read:blocks"]} when action == :blocks
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:blocks"]} when action in [:block, :unblock]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:follows"]} when action in [:relationships, :familiar_followers]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["follow", "write:follows"]}
    when action in [:follow_by_uri, :follow, :unfollow, :remove_from_followers]
  )

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:mutes"]} when action == :mutes)

  plug(OAuthScopesPlug, %{scopes: ["follow", "write:mutes"]} when action in [:mute, :unmute])

  @relationship_actions [:follow, :unfollow, :remove_from_followers]
  @needs_account ~W(
    followers following lists follow unfollow mute unmute block unblock
    note endorse unendorse remove_from_followers
  )a

  plug(
    RateLimiter,
    [name: :relation_id_action, params: ["id", "uri"]] when action in @relationship_actions
  )

  plug(RateLimiter, [name: :relations_actions] when action in @relationship_actions)
  plug(RateLimiter, [name: :app_account_creation] when action == :create)
  plug(:assign_account_by_id when action in @needs_account)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AccountOperation

  @doc "POST /api/v1/accounts"
  def create(
        %{assigns: %{app: app}, private: %{open_api_spex: %{body_params: params}}} = conn,
        _params
      ) do
    with :ok <- validate_email_param(params),
         :ok <- TwitterAPI.validate_captcha(app, params),
         {:ok, user} <- TwitterAPI.register_user(params),
         {_, {:ok, token}} <-
           {:login, OAuthController.login(user, app, app.scopes)} do
      OAuthController.after_token_exchange(conn, %{user: user, token: token})
    else
      {:login, {:account_status, :confirmation_pending}} ->
        json_response(conn, :ok, %{
          message: "You have been registered. Please check your email for further instructions.",
          identifier: "missing_confirmed_email"
        })

      {:login, {:account_status, :approval_pending}} ->
        json_response(conn, :ok, %{
          message:
            "You have been registered. You'll be able to log in once your account is approved.",
          identifier: "awaiting_approval"
        })

      {:login, _} ->
        json_response(conn, :ok, %{
          message:
            "You have been registered. Some post-registration steps may be pending. " <>
              "Please log in manually.",
          identifier: "manual_login_required"
        })

      {:error, error} ->
        json_response(conn, :bad_request, %{error: error})
    end
  end

  def create(%{assigns: %{app: _app}} = conn, _) do
    render_error(conn, :bad_request, "Missing parameters")
  end

  def create(conn, _) do
    render_error(conn, :forbidden, "Invalid credentials")
  end

  defp validate_email_param(%{email: email}) when not is_nil(email), do: :ok

  defp validate_email_param(_) do
    case Pleroma.Config.get([:instance, :account_activation_required]) do
      true -> {:error, dgettext("errors", "Missing parameter: %{name}", name: "email")}
      _ -> :ok
    end
  end

  @doc "GET /api/v1/accounts/verify_credentials"
  def verify_credentials(%{assigns: %{user: user}} = conn, _) do
    chat_token = Phoenix.Token.sign(conn, "user socket", user.id)

    render(conn, "show.json",
      user: user,
      for: user,
      with_pleroma_settings: true,
      with_chat_token: chat_token
    )
  end

  @doc "PATCH /api/v1/accounts/update_credentials"
  def update_credentials(
        %{assigns: %{user: user}, private: %{open_api_spex: %{body_params: params}}} = conn,
        _params
      ) do
    params =
      params
      |> Enum.filter(fn {_, value} -> not is_nil(value) end)
      |> Enum.into(%{})

    # We use an empty string as a special value to reset
    # avatars, banners, backgrounds
    user_image_value = fn
      "" -> {:ok, nil}
      value -> {:ok, value}
    end

    user_params =
      [
        :no_rich_text,
        :hide_followers_count,
        :hide_follows_count,
        :hide_followers,
        :hide_follows,
        :hide_favorites,
        :show_role,
        :skip_thread_containment,
        :allow_following_move,
        :also_known_as,
        :accepts_chat_messages,
        :show_birthday
      ]
      |> Enum.reduce(%{}, fn key, acc ->
        Maps.put_if_present(acc, key, params[key], &{:ok, Params.truthy_param?(&1)})
      end)
      |> Maps.put_if_present(:name, params[:display_name])
      |> Maps.put_if_present(:bio, params[:note])
      |> Maps.put_if_present(:raw_bio, params[:note])
      |> Maps.put_if_present(:avatar, params[:avatar], user_image_value)
      |> Maps.put_if_present(:banner, params[:header], user_image_value)
      |> Maps.put_if_present(:background, params[:pleroma_background_image], user_image_value)
      |> Maps.put_if_present(
        :raw_fields,
        params[:fields_attributes],
        &{:ok, normalize_fields_attributes(&1)}
      )
      |> Maps.put_if_present(:pleroma_settings_store, params[:pleroma_settings_store])
      |> Maps.put_if_present(:default_scope, params[:default_scope])
      |> Maps.put_if_present(:default_scope, params["source"]["privacy"])
      |> Maps.put_if_present(:actor_type, params[:bot], fn bot ->
        if bot, do: {:ok, "Service"}, else: {:ok, "Person"}
      end)
      |> Maps.put_if_present(:actor_type, params[:actor_type])
      |> Maps.put_if_present(:also_known_as, params[:also_known_as])
      # Note: param name is indeed :locked (not an error)
      |> Maps.put_if_present(:is_locked, params[:locked])
      # Note: param name is indeed :discoverable (not an error)
      |> Maps.put_if_present(:is_discoverable, params[:discoverable])
      |> Maps.put_if_present(:birthday, params[:birthday])
      |> Maps.put_if_present(:language, Pleroma.Web.Gettext.normalize_locale(params[:language]))
      |> Maps.put_if_present(:avatar_description, params[:avatar_description])
      |> Maps.put_if_present(:header_description, params[:header_description])

    # What happens here:
    #
    # We want to update the user through the pipeline, but the ActivityPub
    # update information is not quite enough for this, because this also
    # contains local settings that don't federate and don't even appear
    # in the Update activity.
    #
    # So we first build the normal local changeset, then apply it to the
    # user data, but don't persist it. With this, we generate the object
    # data for our update activity. We feed this and the changeset as meta
    # information into the pipeline, where they will be properly updated and
    # federated.
    with changeset <- User.update_changeset(user, user_params),
         {:ok, unpersisted_user} <- Ecto.Changeset.apply_action(changeset, :update),
         updated_object <-
           Pleroma.Web.ActivityPub.UserView.render("user.json", user: unpersisted_user)
           |> Map.delete("@context"),
         {:ok, update_data, []} <- Builder.update(user, updated_object),
         {:ok, _update, _} <-
           Pipeline.common_pipeline(update_data,
             local: true,
             user_update_changeset: changeset
           ) do
      render(conn, "show.json",
        user: unpersisted_user,
        for: unpersisted_user,
        with_pleroma_settings: true
      )
    else
      {:error, %Ecto.Changeset{errors: [avatar: {"file is too large", _}]}} ->
        render_error(conn, :request_entity_too_large, "File is too large")

      {:error, %Ecto.Changeset{errors: [banner: {"file is too large", _}]}} ->
        render_error(conn, :request_entity_too_large, "File is too large")

      {:error, %Ecto.Changeset{errors: [background: {"file is too large", _}]}} ->
        render_error(conn, :request_entity_too_large, "File is too large")

      {:error, %Ecto.Changeset{errors: [{:bio, {_, _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "Bio is too long")

      {:error, %Ecto.Changeset{errors: [{:name, {_, _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "Name is too long")

      {:error, %Ecto.Changeset{errors: [{:avatar_description, {_, _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "Avatar description is too long")

      {:error, %Ecto.Changeset{errors: [{:header_description, {_, _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "Banner description is too long")

      {:error, %Ecto.Changeset{errors: [{:fields, {"invalid", _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "One or more field entries are too long")

      {:error, %Ecto.Changeset{errors: [{:fields, {_, _}} | _]}} ->
        render_error(conn, :request_entity_too_large, "Too many field entries")

      _e ->
        render_error(conn, :forbidden, "Invalid request")
    end
  end

  defp normalize_fields_attributes(fields) do
    if(Enum.all?(fields, &is_tuple/1), do: Enum.map(fields, fn {_, v} -> v end), else: fields)
    |> Enum.map(fn
      %{} = field -> %{"name" => field.name, "value" => field.value}
      field -> field
    end)
  end

  @doc "GET /api/v1/accounts/relationships"
  def relationships(
        %{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn,
        _
      ) do
    targets = User.get_all_by_ids(List.wrap(id))

    render(conn, "relationships.json", user: user, targets: targets)
  end

  # Instead of returning a 400 when no "id" params is present, Mastodon returns an empty array.
  def relationships(%{assigns: %{user: _user}} = conn, _), do: json(conn, [])

  @doc "GET /api/v1/accounts/:id"
  def show(
        %{
          assigns: %{user: for_user},
          private: %{open_api_spex: %{params: %{id: nickname_or_id} = params}}
        } = conn,
        _params
      ) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(nickname_or_id, for: for_user),
         :visible <- User.visible_for(user, for_user) do
      render(conn, "show.json",
        user: user,
        for: for_user,
        embed_relationships: embed_relationships?(params)
      )
    else
      error -> user_visibility_error(conn, error)
    end
  end

  @doc "GET /api/v1/accounts/:id/statuses"
  def statuses(
        %{assigns: %{user: reading_user}, private: %{open_api_spex: %{params: params}}} = conn,
        _params
      ) do
    with %User{} = user <- User.get_cached_by_nickname_or_id(params.id, for: reading_user),
         :visible <- User.visible_for(user, reading_user) do
      params =
        params
        |> Map.delete(:tagged)
        |> Map.put(:tag, params[:tagged])

      activities = ActivityPub.fetch_user_activities(user, reading_user, params)

      conn
      |> add_link_headers(activities)
      |> put_view(StatusView)
      |> render("index.json",
        activities: activities,
        for: reading_user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      error -> user_visibility_error(conn, error)
    end
  end

  defp user_visibility_error(conn, error) do
    case error do
      :restrict_unauthenticated ->
        render_error(conn, :unauthorized, "This API requires an authenticated user")

      _ ->
        render_error(conn, :not_found, "Can't find user")
    end
  end

  @doc "GET /api/v1/accounts/:id/followers"
  def followers(
        %{assigns: %{user: for_user, account: user}, private: %{open_api_spex: %{params: params}}} =
          conn,
        _params
      ) do
    params =
      params
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.into(%{})

    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_followers(user, params)
        user.hide_followers -> []
        true -> MastodonAPI.get_followers(user, params)
      end

    conn
    |> add_link_headers(followers)
    # https://git.pleroma.social/pleroma/pleroma-fe/-/issues/838#note_59223
    |> render("index.json",
      for: for_user,
      users: followers,
      as: :user,
      embed_relationships: embed_relationships?(params)
    )
  end

  @doc "GET /api/v1/accounts/:id/following"
  def following(
        %{assigns: %{user: for_user, account: user}, private: %{open_api_spex: %{params: params}}} =
          conn,
        _params
      ) do
    params =
      params
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.into(%{})

    followers =
      cond do
        for_user && user.id == for_user.id -> MastodonAPI.get_friends(user, params)
        user.hide_follows -> []
        true -> MastodonAPI.get_friends(user, params)
      end

    conn
    |> add_link_headers(followers)
    # https://git.pleroma.social/pleroma/pleroma-fe/-/issues/838#note_59223
    |> render("index.json",
      for: for_user,
      users: followers,
      as: :user,
      embed_relationships: embed_relationships?(params)
    )
  end

  @doc "GET /api/v1/accounts/:id/lists"
  def lists(%{assigns: %{user: user, account: account}} = conn, _params) do
    lists = Pleroma.List.get_lists_account_belongs(user, account)

    conn
    |> put_view(ListView)
    |> render("index.json", lists: lists)
  end

  @doc "POST /api/v1/accounts/:id/follow"
  def follow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not follow yourself"}
  end

  def follow(
        %{
          assigns: %{user: follower, account: followed},
          private: %{open_api_spex: %{body_params: params}}
        } = conn,
        _
      ) do
    with {:ok, follower} <- MastodonAPI.follow(follower, followed, params) do
      render(conn, "relationship.json", user: follower, target: followed)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unfollow"
  def unfollow(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not unfollow yourself"}
  end

  def unfollow(%{assigns: %{user: follower, account: followed}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.unfollow(followed, follower) do
      render(conn, "relationship.json", user: follower, target: followed)
    end
  end

  @doc "POST /api/v1/accounts/:id/mute"
  def mute(
        %{
          assigns: %{user: muter, account: muted},
          private: %{open_api_spex: %{body_params: params}}
        } = conn,
        _params
      ) do
    params =
      params
      |> Map.put_new(:duration, Map.get(params, :expires_in, 0))

    with {:ok, _user_relationships} <- User.mute(muter, muted, params) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unmute"
  def unmute(%{assigns: %{user: muter, account: muted}} = conn, _params) do
    with {:ok, _user_relationships} <- User.unmute(muter, muted) do
      render(conn, "relationship.json", user: muter, target: muted)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/block"
  def block(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, _activity} <- CommonAPI.block(blocked, blocker) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unblock"
  def unblock(%{assigns: %{user: blocker, account: blocked}} = conn, _params) do
    with {:ok, _activity} <- CommonAPI.unblock(blocked, blocker) do
      render(conn, "relationship.json", user: blocker, target: blocked)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/note"
  def note(
        %{
          assigns: %{user: noter, account: target},
          private: %{open_api_spex: %{body_params: %{comment: comment}}}
        } = conn,
        _params
      ) do
    with {:ok, _user_note} <- UserNote.create(noter, target, comment) do
      render(conn, "relationship.json", user: noter, target: target)
    end
  end

  @doc "POST /api/v1/accounts/:id/pin"
  def endorse(%{assigns: %{user: endorser, account: endorsed}} = conn, _params) do
    with {:ok, _user_relationships} <- User.endorse(endorser, endorsed) do
      render(conn, "relationship.json", user: endorser, target: endorsed)
    else
      {:error, message} -> json_response(conn, :bad_request, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/unpin"
  def unendorse(%{assigns: %{user: endorser, account: endorsed}} = conn, _params) do
    with {:ok, _user_relationships} <- User.unendorse(endorser, endorsed) do
      render(conn, "relationship.json", user: endorser, target: endorsed)
    else
      {:error, message} -> json_response(conn, :forbidden, %{error: message})
    end
  end

  @doc "POST /api/v1/accounts/:id/remove_from_followers"
  def remove_from_followers(%{assigns: %{user: %{id: id}, account: %{id: id}}}, _params) do
    {:error, "Can not unfollow yourself"}
  end

  def remove_from_followers(%{assigns: %{user: followed, account: follower}} = conn, _params) do
    with {:ok, follower} <- CommonAPI.reject_follow_request(follower, followed) do
      render(conn, "relationship.json", user: followed, target: follower)
    else
      nil ->
        render_error(conn, :not_found, "Record not found")
    end
  end

  @doc "POST /api/v1/follows"
  def follow_by_uri(%{private: %{open_api_spex: %{body_params: %{uri: uri}}}} = conn, _) do
    case User.get_cached_by_nickname(uri) do
      %User{} = user ->
        conn
        |> assign(:account, user)
        |> follow(%{})

      nil ->
        {:error, :not_found}
    end
  end

  @doc "GET /api/v1/mutes"
  def mutes(%{assigns: %{user: user}} = conn, params) do
    users =
      user
      |> User.muted_users_relation(_restrict_deactivated = true)
      |> Pleroma.Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(users)
    |> render("index.json",
      users: users,
      for: user,
      as: :user,
      embed_relationships: embed_relationships?(params),
      mutes: true
    )
  end

  @doc "GET /api/v1/blocks"
  def blocks(%{assigns: %{user: user}} = conn, params) do
    users =
      user
      |> User.blocked_users_relation(_restrict_deactivated = true)
      |> Pleroma.Pagination.fetch_paginated(params)

    conn
    |> add_link_headers(users)
    |> render("index.json",
      users: users,
      for: user,
      as: :user,
      embed_relationships: embed_relationships?(params)
    )
  end

  @doc "GET /api/v1/accounts/lookup"
  def lookup(%{private: %{open_api_spex: %{params: %{acct: nickname}}}} = conn, _params) do
    with %User{} = user <- User.get_by_nickname(nickname) do
      render(conn, "show.json",
        user: user,
        skip_visibility_check: true
      )
    else
      error -> user_visibility_error(conn, error)
    end
  end

  @doc "GET /api/v1/endorsements"
  def endorsements(%{assigns: %{user: user}} = conn, params) do
    users =
      user
      |> User.endorsed_users_relation(_restrict_deactivated = true)
      |> Pleroma.Repo.all()

    conn
    |> render("index.json",
      users: users,
      for: user,
      as: :user,
      embed_relationships: embed_relationships?(params)
    )
  end

  @doc "GET /api/v1/accounts/familiar_followers"
  def familiar_followers(
        %{assigns: %{user: user}, private: %{open_api_spex: %{params: %{id: id}}}} = conn,
        _id
      ) do
    users =
      User.get_all_by_ids(List.wrap(id))
      |> Enum.map(&%{id: &1.id, accounts: get_familiar_followers(&1, user)})

    conn
    |> render("familiar_followers.json",
      for: user,
      users: users,
      as: :user
    )
  end

  defp get_familiar_followers(%{id: id} = user, %{id: id}) do
    User.get_familiar_followers(user, user)
  end

  defp get_familiar_followers(%{hide_followers: true}, _current_user) do
    []
  end

  defp get_familiar_followers(user, current_user) do
    User.get_familiar_followers(user, current_user)
  end
end
